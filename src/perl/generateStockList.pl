#!/usr/local/bin/perl -I../modules/

=head1 NAME

   generateStockList.pl generates the a tab delimited table for a submission to the stock center

=head1 USAGE

   generateStockList.pl [options] strain1 strain2 ...

=head1 OPTIONS

   -batch <batch_id>  process all strains in the batch
   -skip  <regexp>    skip from processing any strain matching the regexp

   The recheck processing is only useful when -batch is specified:
   -[no]recheck       only include strains for which are [not] rechecked verified
   -[no]all           include all strains whether rechecked or not
                      The default behaviour is -recheck -noall
 
   
=cut

# standard modules used by this script
use Carp;
use Getopt::Long;
use strict;

# modules for pelement processing
use Pelement;
use Session;
use Files;
use PelementDBI;
use Cytology;
use Seq;
use Gel;
use LaneSet;
use Phenotype;
use Phred_Seq;
use SampleSet;
use Seq_AlignmentSet;
use Seq_Assembly;
use Seq_AssemblySet;
use Processing;


use File::Basename;
use Getopt::Long;


# gadfly modules
use lib $ENV{FLYBASE_MODULE_PATH};
use GeneralUtils::XML::Generator;
use GxAdapters::ConnectionManager qw(get_handle close_handle
                             set_handle_readonly);
use GeneralUtils::Structures qw(rearrange);
use GxAdapters::GxAnnotatedSeq;
use GxAdapters::GxGene;
use BioModel::AnnotatedSeq;
use BioModel::Annotation;
use BioModel::Gene;
use BioModel::SeqAlignment;

my $session = new Session();

my $recheck = 1;
my $all = 0;
my @batch = ();
my %strainH;
my @ignore = ();

GetOptions("recheck!" => \$recheck,
           "all!"     => \$all,
           "batch=s@" => \@batch,
           "skip=s@"  => \@ignore,
           );


$session->die("-recheck and -all cannot both be specified.") if $recheck && $all;

my $doc_date = localtime(time);
my $doc_creator = File::Basename::basename($0).':$Revision$';
$doc_creator =~ s/[ \$]//g;

# we pass either a option specified -batch or a list of strains.
# we may also have a list of excluded strains with a -skip <strain>
# everything left on the list is a strain.

map { $strainH{$_} = 1 } @ARGV;

# and add to it the strains from the batches
foreach my $b (@batch) {
   my $samples = new SampleSet($session,{-batch_id=>$b})->select;
   map { $strainH{$_->strain_name} = 1 } $samples->as_list;
}

# now get rid of the skips
foreach my $skip (@ignore) {
   map { delete $strainH{$_} } grep(/$skip/, keys %strainH);
}

$session->info("There are ".scalar(keys %strainH)." strains left on the list to process.");

foreach my $strain (sort keys %strainH) {

   $session->info("Processing $strain.");

   my $laneSet = new LaneSet($session,{-seq_name=>$strain})->select;
   ($session->warn("No data for strain named $strain") and next)
                                                    unless $laneSet->as_list;

   # default operation if batch was not specified is to consider it a 'pass'
   my $pass = 1;
   # we need to go through this set of lanes and make sure we have data from this batch
   $pass = verifyLaneInBatch($session,$laneSet,@batch) if @batch;

   if ($all || ($recheck && $pass)  || (!$recheck && !$pass) ) {
      my @insertList = getCytoAndGene($session,$strain);
      if (scalar(@insertList) > 1) {
         map {print "$strain,",$_->{arm},",",$_->{range},",",$_->{band},",",join(" ",@{$_->{gene}}),"\n" } @insertList;
      } elsif (scalar(@insertList)) {
         map {print "$strain,",$_->{arm},",",$_->{range},",",$_->{band},",",join(" ",@{$_->{gene}}),"\n" } @insertList;
      } else {
         print "$strain,,\n";
      }
   } else {
      $session->info("$strain results skipped; not rechecked verified.") if !$pass;
      $session->info("$strain results skipped; rechecked verified.") if $pass;
   }

}

sub verifyLaneInBatch
{
   my $session = shift;
   my $laneSet = shift;
   my @batch = @_;

   # we need to 1) verify at least one lane contained in the lane set has
   # one of the batch id's on the batch list and 2) one or the other
   # ends from that batch be used to build a consensus sequence

   my %batchH = ();
   foreach my $lane ($laneSet->as_list) {
      my $gel = new Gel($session,{-id=>$lane->gel_id})->select_if_exists;
      next unless $gel->id;
      map { $batchH{$_} = 1 if Processing::batch_id($gel->ipcr_name) eq $_ } @batch;
   }
      
   ($session->info("No lanes in the listed batch.") and return) unless keys %batchH;
 
   $session->die("This is too complicated right now.") if scalar(keys %batchH) > 1;
   
   my $thisBatch = (keys %batchH)[0];
   foreach my $lane ($laneSet->as_list) {
      my $gel = new Gel($session,{-id=>$lane->gel_id})->select_if_exists;
      next unless $gel->id;
      next unless Processing::batch_id($gel->ipcr_name) eq $thisBatch;

      my $p = new Phred_Seq($session,{-lane_id=>$lane->id})->select_if_exists;
      next unless $p->id;
      my $sA = new Seq_Assembly($session,{-src_seq_src=>'phred_seq',
                                          -src_seq_id => $p->id})->select_if_exists;
      next unless $sA->seq_name;
      if (Seq::qualifier($sA->seq_name) ) {
         $session->info("A lane was used in a qualified sequence.");
      } else {
         $session->info("A lane was used in an unqualified sequence.");
         # and, as the final check, this must be assembled with something else
         my $final = new Seq_AssemblySet($session,{-src_seq_src=>'phred_seq',
                                                   -seq_name   => $sA->seq_name})->select;
         map { ($session->info("This lane was assembled with earlier data.") and
                          return 1) if $_->src_seq_id < $sA->src_seq_id } $final->as_list;

         $session->info("But this lane was not assembled with earlier data.");

      }
   }

   return 0;
}

sub getCytoAndGene
{
   my $session = shift;
   my $strain = shift;


   # we need to look at the alignments for the unqualified sequences.
   # and look for if we have the mappable insertions.
   my @insertList = ();
   foreach my $end qw(3 5) {
      my $saS = new Seq_AlignmentSet($session,{-seq_name=>$strain.'-'.$end})->select;
      foreach my $sa ($saS->as_list) {
         next if $sa->status eq 'deselected';
         next if $sa->status eq 'multiple';

         my $isNewInsertion = 1;
         foreach my $in (@insertList) {
           if ($in->{arm} eq $sa->scaffold && closeEnuf($in->{range},$sa->s_insert)) {
              $in->{range} = mergeRange($in->{range},$sa->s_insert);
              $isNewInsertion = 0;
              last;
           }
         }
         if ($isNewInsertion) {
            push @insertList, {arm   => $sa->scaffold,
                               range => $sa->s_insert.":".$sa->s_insert,
                               band  => '',
                               gene  => [] };
         }
      }
   }
   my $gadflyDba;
   $ENV{GADB_SUPPRESS_RESIDUES} = 1;
   foreach my $in (@insertList) {
      my ($start,$end) = split(/:/,$in->{range});
      my $arm = $in->{arm};
      my $cyto;
      if ($arm =~ s/arm_// ) {
         $cyto = new Cytology($session,{scaffold=>$in->{arm},
                                    less_than=>{start=>$end},
                        greater_than_or_equal=>{stop=>$start}})->select_if_exists;
         $in->{band} = $cyto->band;
         $in->{arm} =~ s/arm_//;
      } else {
         $in->{band} = 'Het';
      }

      $session->log($Session::Info,
                      "Looking at hit on $arm at position range ".$in->{range});
      if (grep(/$arm$/,qw(2L 2R 3L 3R 4 X)) ) {
         # euchromatic release 3 arm
         $gadflyDba = GxAdapters::ConnectionManager->get_adapter("gadfly");
      } else {
         # unmapped heterchromatic or shotgun arm extension
         $gadflyDba = GxAdapters::ConnectionManager->get_adapter("gadfly");
         $arm = 'X.wgs3_centromere_extensionB'
                                 if $arm eq 'X.wgs3_centromere_extension';
      }

      my @annot = ();

      eval {
         my $seqs = $gadflyDba->get_AnnotatedSeq(
                   {range=>"$arm:$start..$end",type=>'gene'},['-results']);
         @annot = $seqs->annotation_list()?@{$seqs->annotation_list}:();
      };

      $session->log($Session::Info,"Found ".scalar(@annot)." genes.");

      # look at each annotation and decide if we're inside it.

      foreach my $annot (@annot) {
          next unless $annot->gene;
          my $gene = $annot->gene;
          # if this isn't a real gene, we gotta skip it
          next unless $gene->flybase_accession_no;
          next unless $gene->name =~ /^CG\d+$/;
          push @{$in->{gene}}, $gene->name;
          $session->log($Session::Info, "Hit ".$gene->name." (".$gene->flybase_accession_no->acc_no.").");
      }
      $gadflyDba->close;
   }

   # if possible, we'll update the phenotype/genotype list
   if (scalar(@insertList) == 1) {
      my $pheno = new Phenotype($session,{-strain_name=>$strain})->select_if_exists;
      my $in = $insertList[0];
      if ($in->{band} && !$pheno->derived_cytology) {
         $pheno->derived_cytology($in->{band});
         if ($pheno->id) {
            $session->info("Updating cytology info for $strain");
            $pheno->update;
         } else {
            $session->info("Inserting cytology info for $strain");
            $pheno->insert;
         }
      }
   }

   return @insertList;

}

sub closeEnuf
{
  my $range = shift;
  my $point = shift;
  my ($a,$b) = split(/:/,$range);
  return 1 if ($a-10000<$point && $b+10000>$point);
}
sub mergeRange
{
  my $range = shift;
  my $point = shift;
  my @range = split(/:/,$range);
  @range = sort {$a <=> $b} (@range,$point);
  return $range[0].":".$range[-1];
}
