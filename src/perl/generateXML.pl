#!/usr/local/bin/perl -I../modules/

=head1 NAME

   generateXML.pl dump the xml for a genbank unit of annotation data
   with P element insertions

=head1 USAGE

   generateXML.pl [options]

=head1 CREDITS

  This script bears more than a coincidental resemblance to dump_generegions.pl

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
use Strain;
use Blast_ReportSet;
use Blast_Report;
use Gadfly_Syn;


# gadfly modules
use lib $ENV{FLYBASE_MODULE_PATH};
use GeneralUtils::XML::Generator;
use GxAdapters::ConnectionManager qw(get_handle close_handle
                             set_handle_readonly);
use GeneralUtils::Structures qw(rearrange);
use GxAdapters::GxAnnotatedSeq;

use BioModel::AnnotatedSeq;
use BioModel::Annotation;
use BioModel::Gene;
use BioModel::SeqAlignment;

my $session = new Session();


# how will we do this? by coordinates; by gene regions??
my $arm;
my $start;
my $end;
my $gbUnit;
my $db = 'gadflyi';
GetOptions("arm=s"   => \$arm,
           "start=i" => \$start,
           "end=i"   => \$end,
           "gb=s"    => \$gbUnit,
           "db=s"    => \$db);

# set up the gadfly database handle
my $dbh = GxAdapters::ConnectionManager::get_handle($db);
set_handle_readonly($dbh);
$ENV{GADB_SUPPRESS_RESIDUES} = 1;

# for now, require coordinates or gb unit
$start = $start || 0;
die unless (($arm && $end) || $gbUnit);

my $gadfly_name = $gbUnit;
if ($gbUnit) {
   # there are some modifications of scaffold extension names
   # between (gadfly) => (pelement) if there is a synonym, use if
   my $gadfly_syn = new Gadfly_Syn($session,
                   {-pelement_scaffold=>$gbUnit})->select_if_exists;
   $gadfly_name = $gadfly_syn->gadfly_scaffold
                       if $gadfly_syn && $gadfly_syn->gadfly_scaffold;

   $session->log($Session::Info,
        "Scaffold name $gbUnit has gadfly name $gadfly_name.")
                                         if $gadfly_name ne $gbUnit;
}
 
my %centromere_name_map = (
#            '2R.wgs3_centromere_extension' => '2R.wgs3_centromere',
#            '3L.wgs3_centromere_extension' => '3L.wgs3_centromere',
#            'X.wgs3_centromere_extensionB' => 'X.wgs3_centromere',
#            '3R.wgs3_centromere_extension' => '3R.wgs3_centromere',
#            '2L_wgs3_centromere_extension' => '2L.wgs3_centromere',
             );

# trim off a possible arm_ prefix to talk to gadfly
$arm =~ s/^arm_//;

# and the annotated sequence
my $v_annseq;
if ($gbUnit) {
   $v_annseq = GxAdapters::GxAnnotatedSeq->select_obj($dbh,
                    {name=>$gadfly_name},["result_span_data","visual"]);
   # for arm U, we keep the scaffold number as the arm; otherwise
   # we use the euchromatin coordinates.
   $arm = $v_annseq->segment->arm;
   if (grep(/$arm/,qw(2L 2R 3L 3R 4 X)) ) {
      $arm = "arm_".$v_annseq->segment->arm;
      $start = $v_annseq->segment->start;
      $end = $v_annseq->segment->end;
      $session->log($Session::Info,"Genbank unit has range $arm:$start..$end.");
   } else {
      $arm = $centromere_name_map{$gbUnit} || $gbUnit;
      $start = 0;
      $end = $v_annseq->segment->end-$v_annseq->segment->start;
      $session->log($Session::Info,"Genbank unit is an unmapped scaffold.");
      $session->log($Session::Info,"Coordinate span is $start to $end.");
   }
} else {
   $v_annseq = GxAdapters::GxAnnotatedSeq->select_obj($dbh,
                  {range=>"$arm:$start..$end"},["result_span_data","visual"]);
   $arm = "arm_".$arm;
}

# hack and find the corresponding pelement insertions.
# this needs to be cleaned up.
my @insertions = ();
$session->db->select(
       qq(
          select s.seq_name,s.strain_name,s_insert,(p_end-p_start)/abs(p_end-p_start),
          g.status from seq_alignment a,seq s left outer join
          strain g on g.strain_name=s.strain_name where
          scaffold = '$arm' and s_insert<=$end and s_insert>=$start and
          a.seq_name=s.seq_name and (a.status='unique' or a.status='curated')),
          \@insertions);


$session->log($Session::Info,"Found ".scalar(@insertions)/5 .
                                      " insertions on arm $arm.");

$session->log($Session::Error,"Can't find seq.") unless $v_annseq;

# insert a computational analysis for each insertion in this range
my %inserts = ();
my $insertCtr = 0;

# here's a hash of the annotated genes to associate with each insertion
my @annot = $v_annseq->annotation_list()?@{$v_annseq->annotation_list}:();

my @scaffoldGenes = ();
foreach my $annot (@annot) {
   next unless $annot->gene;
   my $geneStrand = ($annot->gene->end > $annot->gene->start)?+1:-1;
   push @scaffoldGenes, {strand=>$geneStrand, pos=>$annot->gene->start};
}

while(@insertions) {
   my ($seq_name,$strain_name,$gstart,$strand,$status) = splice(@insertions,0,5);
   my $gend;
   next if $inserts{$seq_name};
   $inserts{$seq_name} = 1;
   if ($strand > 0 ) {
      $gend = $gstart + 2;
   } else {
      $gend = $gstart - 2;
   }
   $session->log($Session::Info,"Added $seq_name at $gstart on strand $strand.");

   # make this relative to the segment
   $gstart -= $start;
   $gend -= $start;

   my $new_ana = new BioModel::ComputationalAnalysis;
   $new_ana->program("PelementPipeline");

   # our database is really a collection identifier
   my $strain = new Strain($session,{-strain_name=>$strain_name})->select();
   my $coll = $strain->collection;
   # the collection may include a 'subcollection' qualifier. delete it.
   $coll =~ s/\..*//;
   $strain->collection("Other") unless grep (/^$coll$/,qw(CC EY KV KG PL PB));
   $new_ana->database($strain->collection);

   my $new_rset = BioModel::ResultSet->create_from_coords(-start=>$gstart,
                                     -end=>$gend,-src_seq=>$v_annseq->seq,
                                     -name=>$seq_name);

   $new_rset->id_space("P element insertion");
   $new_rset->id($insertCtr);
   $insertCtr++;
   my ($score,$percent);
   if (my $scoreIsPercent = 0) {
      # what is the identity?
      $session->db->select_values(
                  qq(select score,percent from blast_report
                     where seq_name='$seq_name'
                     and name='$arm' order by score desc limit 1),
                     [\$score,\$percent]);
      $session->log($Session::Info,
        "old way: Blast score and percent identifty for $seq_name is $score $percent.");
      my $blastReportSet = new Blast_ReportSet($session,{-seq_name=>$seq_name,-name=>"$arm"})->select();
      my $blastHit = (sort {$a->score <=> $b->score} $blastReportSet->as_list)[-1];
      $session->log($Session::Info,
        "new way: Blast score and percent identifty for $seq_name is ".$blastHit->score." and ".$blastHit->percent);
      $score = $percent;
   } else {
      my $nearby = "";
      foreach my $scaffoldGene (@scaffoldGenes) {
         next unless $scaffoldGene->{strand} == $strand;
         if ($nearby eq "" || abs($nearby)>abs($scaffoldGene->{pos}-$gstart) ) {
            $nearby = abs($scaffoldGene->{pos}-$gstart);
         }
      }
      $score = $nearby;
   }

   my $newSeqF = new BioModel::SeqFeature();
   $newSeqF->src_seq(new BioModel::Seq);
   $newSeqF->src_seq->name($seq_name);
   if ($status) {
      $newSeqF->src_seq->description("Status '$status'");
   } else {
      $newSeqF->src_seq->description("Status field not set");
   }

   # does this do the right things?
   $newSeqF->start(0);
   $newSeqF->end(2);

   # overkill: there is only 1 element in the list
   map { $_->type("alignment") } @{$new_rset->result_span_list};
   map { $_->set_score('score',$score) } @{$new_rset->result_span_list};
   map { $_->subject_extent($newSeqF) }  @{$new_rset->result_span_list};
   map { $_->name('Insertion') } @{$new_rset->result_span_list};

   $new_ana->result_set_list([$new_rset]);
   $v_annseq->add_analysis($new_ana);

   # now we add keepers to yet another tier
   if ($status eq 'permanent') {
      my $new_new_ana = $new_ana->duplicate();
      $new_new_ana->program("PelementPipeline");
      $new_new_ana->database("Permanent Collection");
      $v_annseq->add_analysis($new_new_ana);
   } elsif ($status eq 'new' ) {
      my $new_new_ana = $new_ana->duplicate();
      $new_new_ana->program("PelementPipeline");
      $new_new_ana->database("New Insertion");
      $v_annseq->add_analysis($new_new_ana);
   }

}

# create a new xml generator object and write to a file with
# a name formatted to include arm and coordinates

my $fn = xml_filename(-name=>$gbUnit,-arm=>$arm,-start=>$start,-end=>$end,-size=>$start-$end);
my $xml_generator = GeneralUtils::XML::Generator->new(-file=>$fn);
$v_annseq->to_xml($xml_generator, {no_residues=>1});  # suppress residues

$xml_generator->kill;
     
$session->log($Session::Info,"Generated $fn.");

# done!
GxAdapters::GxAnnotation->clear_memory_cache($dbh,"all");
close_handle($dbh);

(Files::copy($fn,$PELEMENT_XML) && Files::delete($fn)) ||
     $session->log($Session::Warn,"Some trouble renaming file: $!");

$session->exit();

sub xml_filename {
    my ($name, $arm, $start, $end, $size) =
                         rearrange([qw(name arm start end size)], @_);
    return "$name.xml" if $name;
    return "$arm.$start-$end.xml";
}
