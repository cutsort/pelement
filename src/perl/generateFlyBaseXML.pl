#!/usr/local/bin/perl -I../modules/

=head1 NAME

   generateFlyBaseXML.pl generates the xml for a submission to FlyBase

=head1 USAGE

   generateFlyBaseXML.pl [options] strain1 strain2 ...

=cut

# standard modules used by this script
use Carp;
use Getopt::Long;
use strict;

# modules for pelement processing
use Pelement;
use Session;
use Files;
use Cytology;
use PelementDBI;
use Strain;
use SeqSet;
use Seq_AlignmentSet;
use Seq_AssemblySet;
use Gene_AssociationSet;
use Gene_Association;
use Stock_Record;
use Stock_RecordSet;
use Phenotype;
use FlyBase_Submission_Info;
use Submitted_Seq;
use Blast_ReportSet;
use Blast_Report;
use XML::TE_insertion_submission;
use Gadfly_Syn;

use File::Basename;


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

my $doc_date = localtime(time);
my $doc_creator = File::Basename::basename($0).':v$Revision$';
my $sub = new XML::TE_insertion_submission({document_create_date => $doc_date,
                                            document_creator     => $doc_creator});


# extract the first strain name. This will be used to determine
# the collections of this set.
my $strain = $ARGV[0];
unless ($strain) {
   $session->error("No Arg","Need to specify a strain name for submission.");
   exit(2);
}

my $coll = new Strain($session,{-strain_name=>$strain})->select->collection;
unless ($coll) {
   $session->error("No Collection","No collection associated with $strain.");
   exit(2);
}

my $submit_info = new FlyBase_Submission_Info($session,{-collection=>$coll})->select;


$sub->add(new XML::DataSource(
                   {originating_lab      => $submit_info->originating_lab,
                    contact_person       => $submit_info->contact_person,
                    contact_person_email => $submit_info->contact_person_email,
                    project_name         => $submit_info->project_name}));

foreach my $strain_name (@ARGV) {

   my $strain = new Strain($session,{-strain_name=>$strain_name});
   ($session->log($Session::Warn,"No strain named $strain_name") and next)
                                                    unless $strain->db_exists;

   $strain->select;
   if ($coll ne $strain->collection) {
      $session->error("Multiple Collection",
                      "Flybase submission is limited to a single collection per file.");
      exit(2);
   }

   $session->info("Processing strain $strain_name.");

   my $seqSet = new SeqSet($session,
                                {-strain_name=>$strain->strain_name})->select;

   # this will create a list of all alignments associated with the strain,
   # but will not insure that each sequence has an alignment.
   my @seq_alignments = ();
   map { push @seq_alignments,new Seq_AlignmentSet($session,
               {-seq_name=>$_->seq_name})->select->as_list } $seqSet->as_list;
   $session->log($Session::Info,"Looking over ".scalar(@seq_alignments).
                                          " alignments.");

   # alignments are either: 3' end, 5' end, merged ends, or obsolete seq.
   # the obsolete seqs are those in which it was not seen after a crossing
   # and may have been deleted.
   my %align = (3 => [], 5 => [], b => [], o => []);
   foreach my $align (@seq_alignments) {
      next if $align->status eq 'multiple';
      next if $align->status eq 'deselected';
      my $end = Seq::end($align->seq_name);
      my $qual = Seq::qualifier($align->seq_name);
      # we deduce the strand from p_start and p_end
      my $strand = ($align->p_end > $align->p_start)?1:-1;
      $end = 'o' if $qual;
      push @{$align{$end}}, {seq_name => $align->seq_name ,
                             scaffold => $align->scaffold,
                             position => $align->s_insert,
                             strand   => $strand       };
   }
   my $multiple = 'N';
   # check out the alignments. This is a multiple if either (1) any one
   # end has more than 1 unique or curated alignment, of (2) the unique
   # or curated alignment of different ends are on different arms.
   if (scalar(@{$align{3}})>1 || scalar(@{$align{5}}) > 1 ||
                                 scalar(@{$align{b}}) > 1 ) {
      $multiple = 'Y';
   } elsif ( scalar(@{$align{o}})>1 ) {
      $multiple = 'P';
   } else {
      # we have at most 1 alignment per; let's check every combination to
      # see if this is a multiple
      # if there is a conflict between a 3, 5 or b, it's a 'Y'
      if (scalar(@{$align{3}}) && scalar(@{$align{5}})) {
         my $a3 = $align{3}->[0];
         my $a5 = $align{5}->[0];
         $multiple = 'Y' if( $a3->{scaffold} ne $a5->{scaffold} ||
                                abs($a3->{position}-$a5->{position}) > 500);
      } 
      if (scalar(@{$align{3}}) && scalar(@{$align{b}})) {
         my $a3 = $align{3}->[0];
         my $ab = $align{b}->[0];
         $multiple = 'Y' if( $a3->{scaffold} ne $ab->{scaffold} ||
                                abs($a3->{position}-$ab->{position}) > 500);
      }
      if (scalar(@{$align{b}}) && scalar(@{$align{5}})) {
         my $ab = $align{b}->[0];
         my $a5 = $align{5}->[0];
         $multiple = 'Y' if( $ab->{scaffold} ne $a5->{scaffold} ||
                                abs($ab->{position}-$a5->{position}) > 500);
      }
      # if there is a conflict between a o and either a 3, 5, or b, it's a 'P'
      if (scalar(@{$align{3}}) && scalar(@{$align{o}})) {
         my $a3 = $align{3}->[0];
         my $ao = $align{o}->[0];
         $multiple = 'P' if( $multiple eq 'N' && ( $a3->{scaffold} ne $ao->{scaffold} ||
                                abs($a3->{position}-$ao->{position}) > 500));
      } 
      if (scalar(@{$align{o}}) && scalar(@{$align{b}})) {
         my $ao = $align{o}->[0];
         my $ab = $align{b}->[0];
         $multiple = 'P' if( $multiple eq 'N' && ( $ao->{scaffold} ne $ab->{scaffold} ||
                                abs($ao->{position}-$ab->{position}) > 500));
      }
      if (scalar(@{$align{o}}) && scalar(@{$align{5}})) {
         my $ao = $align{o}->[0];
         my $a5 = $align{5}->[0];
         $multiple = 'P' if( $multiple eq 'N' && ( $ao->{scaffold} ne $a5->{scaffold} ||
                                abs($ao->{position}-$a5->{position}) > 500));
      }
   }

   # prepare this for later
   my $stock_record_set = new Stock_RecordSet($session,{-strain_name=>$strain_name})->select;

   my $pheno = new Phenotype($session,{-strain_name=>$strain_name})->select_if_exists;

   # if there is no derived cytology record, we'll try to infer one if the insertion
   # appears to be unique
   my $cyto;

   if ($multiple eq 'N' && $pheno && !$pheno->derived_cytology) {
      my $w;
      if (@{$align{b}}) {
         $w = 'b';
      } elsif ( @{$align{5}}) {
         $w = '5';
      } elsif ( @{$align{3}}) {
         $w = '3';
      }
      if ($w) {
         $cyto = new Cytology($session,{scaffold=>$align{$w}->[0]->{scaffold},
                                       less_than=>{start=>$align{$w}->[0]->{position}},
                           greater_than_or_equal=>{stop=>$align{$w}->[0]->{position}}})->select_if_exists;
         if ($cyto) {
            $pheno->derived_cytology($cyto->band);
            if ($pheno->id) {
               $session->info("Updating cytology info for $strain_name");
               $pheno->update;
            } else {
               $session->info("Inserting cytology info for $strain_name");
               $pheno->insert;
            }
         }
      }
   }
        
   my %stock_numbers = ();
   map { $stock_numbers{$_->stock_number} = 1 } $stock_record_set->as_list;

   my $line = new XML::Line({line_id => $strain->strain_name,
                             is_multiple_insertion_line => $multiple,
                             comment => $pheno->strain_comment
                          });
   $sub->add($line);

   # the problem remains on how to deal with the separate sequences. Are they
   # individual insertions? or are they separate elements of insertion data
   # for one insertion? or as they separate flanking sequences for the same
   # insertion data?
   # look at all the sequences, and handle an each insertion for each as a separate
   # insertion. For each insertion, try to grab other sequence alignments that map to
   # the same genome location and call them parts of the same insertion data.
   # at the end, if we have any sequences without alignments left over, record them as
   # unaligned flanking sequences.

   # something to record which seq's we've looked at.
   my %handled_seqs = ();

   my $insert;

   # and add the annotated gene hits. We'll process this list and
   # assign them to the 'best' alignment.
   my @annotatedHit = getAnnotatedHits($session,$strain->strain_name);

   # we'll keep a list of the insertion data. At the end, we'll tie together
   # the insertion data with the gene annotations and insert everything into the
   # insertion element
   my @insertionData = ();
 
   foreach my $seq ($seqSet->as_list) {
      # we loop through all sequences, trying to bundle together sequences that
      # are part of the same insertion.

      # in case we've already dealt with this before, we skip and go on
      next if $handled_seqs{$seq->seq_name};

      $handled_seqs{$seq->seq_name} = 1;

      # create the insert record, but defer inserting the insert until
      # we're sure there is data to go there.
      my $addThisInsert = 0;
      $insert = new XML::Insertion(
                            {transposon_symbol => $submit_info->transposon_symbol });

      my $insertData = new XML::InsertionData({is_homozygous_viable=>uc($pheno->is_homozygous_viable),
                                               is_homozygous_fertile=>uc($pheno->is_homozygous_fertile),
                                               associated_aberration=>$pheno->associated_aberration,
                                               derived_cytology=>$pheno->derived_cytology,
                                               comment=>$pheno->phenotype_comment});

      # have we put this insertData into the insert?
      my $addThisInsertData = 0;
      map { $insert->add(new XML::Stock({stock_center=>'Bloomington',
                                         stock_id => $_})) } keys %stock_numbers;

      my $end = $seq->end;
      my $flankSeq = new XML::FlankSeq({flanking=>$end,
             position_of_first_base_of_target_sequence =>$seq->insertion_pos});
      # make sure this was submitted
      my $submitted_seq = new Submitted_Seq($session,{-seq_name=>$seq->seq_name})->select_if_exists;
      next unless $submitted_seq->gb_acc;
    
      my $acc = new XML::GBAccno(
                            {accession_version=>$submitted_seq->gb_acc});
      $flankSeq->add($acc);
      $insertData->add($flankSeq);

      # once the insertData has a flank, we can add it to the xml
      unless ($addThisInsertData) {
         $insert->add($insertData);
         $addThisInsertData = 1;
         unless ($addThisInsert) {
            $line->add($insert);
            $addThisInsert = 1;
         }
      }

      my ($arm,$strand,@pos_range) = getAlignmentFromSeqName($seq->seq_name,\%align);
      
      unless ($arm && @pos_range) {
         # sometime the alignment is indirect: the sequence was built from the
         # sequences that had been mapped.
         my $s_aSet = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name,
                                                    -src_seq_src=>'seq'})->select;
         my @baseSeq = ();
         map { push @baseSeq, new SeqSet($session,{-id=>$_->src_seq_id})->select->as_list } $s_aSet->as_list;
            
         foreach my $s (@baseSeq) {
            # we're assuming that the composite seq is built from the seq's from the
            # same strain name; so we don't need to retrieve the seq alignments again
            my ($this_arm,$this_strand,@this_pos) = getAlignmentFromSeqName($s->seq_name,\%align);
            $arm ||= $this_arm;
            $strand ||= $this_strand;
            @pos_range = sort { $a <=> $b } (@pos_range,@this_pos);
            @pos_range = ($pos_range[0],$pos_range[-1]) if @pos_range;
            
         }
      }

      # if this seq is mapped, look for others that are nearby
      if ($arm && $strand && @pos_range) {
         # now look through all the other sequences for things that map nearby
         foreach my $end qw(3 5 b) {
            foreach my $alignHR (@{$align{$end}}) {
               my $this_seq_name = $alignHR->{seq_name};

               next if $handled_seqs{$this_seq_name};

               my $this_arm = $alignHR->{scaffold};
               my $this_pos = $alignHR->{position};
               my $this_strand = $alignHR->{strand};
               $this_arm =~ s/arm_//;
               next if (($this_arm ne $arm) || ($this_strand != $strand)
                                            || ($pos_range[0] - $this_pos > 500)
                                            || ($this_pos - $pos_range[-1] > 500) );

               # ok. this seq is nearby; we need to say we've handled this one
               # and let the limits creep.
               $handled_seqs{$this_seq_name} = 1;
               $pos_range[0] = $this_pos if $this_pos < $pos_range[0];
               $pos_range[-1] = $this_pos if $this_pos > $pos_range[-1];

               # was this submitted? If not we cannot add it to the flank seq
               my $submitted_seq = new Submitted_Seq($session,
                                     {-seq_name=>$this_seq_name})->select_if_exists;
               next unless $submitted_seq->gb_acc;

               # I know I asked you this already, but what what that insertion position again?
               my $this_seq_pos = new Seq($session,{-seq_name=>$this_seq_name})->select->insertion_pos;

               my $flankSeq = new XML::FlankSeq({flanking=>$end,
                      position_of_first_base_of_target_sequence =>$this_seq_pos});
               $flankSeq->add(new XML::GBAccno(
                                     {accession_version=>$submitted_seq->gb_acc}));
               $insertData->add($flankSeq);
            }
         }

         if ( grep(/$arm/,qw(X 2L 2R 3L 3R 4)) ) {
            $insertData->add(new XML::GenomePosition(
                                      { genome_version => 3,
                                        arm            => $arm,
                                        strand         => ($strand>0)?'p':'m',
                                        location       => ($pos_range[0]==$pos_range[1])?
                                                           $pos_range[0]:
                                                           $pos_range[0]."..".$pos_range[1] }));
         } elsif ( $arm =~ /^210000222/ ) {
            my $gs = new GenBankScaffold($session,{-arm=>$arm})->select;
            next unless $gs->accession;
            my $sp = new XML::ScaffoldPosition(
                           { location => ($pos_range[0]==$pos_range[1])?
                                          $pos_range[0]:
                                          $pos_range[0]."..".$pos_range[1],
                             comment => 'Unmapped heterochromatic scaffold' });
            $sp->add(new XML::GBAccno({accession_version => $gs->accession}));
            $insertData->add($sp);
         }

         # we'll report genes only if this is a single insertion
         # and there is not conflicting data.
         my @geneHit = getGeneHit($session,$arm,$strand,@pos_range);
         map { $insertData->add($_) } @geneHit;

         # now add this insertiondata to the list
         push @insertionData, {xml => $insertData,
                               arm => $arm,
                            strand => $strand,
                             start => $pos_range[0],
                               end => $pos_range[-1]}

      }
   }

   # now tie the annotated genes with the insertions.
   foreach my $annot (@annotatedHit) {
      my $bestInsert;
      foreach my $insert (@insertionData) {
         $bestInsert = $insert if (!$bestInsert && $annot->{arm} eq $insert->{arm});
         $bestInsert = $insert if ($bestInsert && $annot->{arm} eq $insert->{arm} &&
                                   abs($insert->{start}-$annot->{start}) <
                                         abs($bestInsert->{start}-$annot->{start}));
      }
      $session->warn("Cannot determine insertion for curated gene ".$annot->{name}.".") and
                  next unless $bestInsert;
      my $localGene = new XML::LocalGene({fbgn=>$annot->{fbgn},
                                          cg_number => $annot->{name}});
      $localGene->attribute(fb_transcript_symbol=>$annot->{transcript}) if $annot->{transcript};

      my $rel = ($annot->{strand} eq $insert->{strand})?'p':'m';
      my $affGene = new XML::AffectedGene({rel_orientation=>$rel,
                                           comment => $annot->{comment}});
      $affGene->add($localGene);
      if ($annot->{transcript}) {
         my $d5 = abs($annot->{start}-$bestInsert->{start})<abs($annot->{start}-$bestInsert->{end})?
                  abs($annot->{start}-$bestInsert->{start}):abs($annot->{start}-$bestInsert->{end});
         my $d3 = abs($annot->{end}-$bestInsert->{start})<abs($annot->{end}-$bestInsert->{end})?
                  abs($annot->{end}-$bestInsert->{start}):abs($annot->{end}-$bestInsert->{end});
         $affGene->attribute(distance_to_transcript_5=>$d5,
                             distance_to_transcript_3=>$d3);
      }
      $bestInsert->{xml}->add($affGene);
   }
}

$sub->validate;

my $fn = 'fly1.xml';

my $xml_generator = GeneralUtils::XML::Generator->new(-file=>$fn);
$xml_generator->header;
$sub->to_xml($xml_generator);

$xml_generator->kill;

$session->exit();


sub getAlignmentFromSeqName
{
   my $seq_name = shift;
   my $aRef = shift;

   my $end = Seq::end($seq_name);

   foreach my $alignHR (@{$aRef->{$end}}) {
      # loop over all the alignments and see if the submitted seq is aligned
      next unless $seq_name eq $alignHR->{seq_name};
      my $arm = $alignHR->{scaffold};
      my $pos = $alignHR->{position};
      my $strand = $alignHR->{strand};
      $arm =~ s/arm_//;
      # the range of the position
      return ($arm,$strand,$pos,$pos);
   }
}

sub getAnnotatedHits
{
   my $session = shift;
   my $strain = shift;

   my $geneSet = new Gene_AssociationSet($session,
                         {-strain_name=>$strain})->select;

   my @geneHits = ();
  
   return @geneHits unless $geneSet->as_list;

   $ENV{GADB_SUPPRESS_RESIDUES} = 1;
   my $gadflyDba = GxAdapters::ConnectionManager->get_adapter("gadflyi");

   foreach my $gene ($geneSet->as_list ) {
      my $g;
      my $fbgn;
      if ($gene->transcript) {
         $gene->transcript($gene->cg.'-R'.$gene->transcript)
                                     if $gene->transcript =~ /^[A-Z]+$/;
         $g = $gadflyDba->get_Transcript({name=>$gene->transcript});
         $session->warn("Cannot get a gadfly CG for annotated transcipt ".$gene->transcript.".") and next
                            unless $g;
         $fbgn = $gadflyDba->get_Gene({name=>$gene->cg});
         $fbgn = $fbgn->flybase_accession_no if $fbgn;
         $fbgn = $fbgn->acc_no if $fbgn;
      } else {
         $g = $gadflyDba->get_Gene({name=>$gene->cg});
         $session->warn("Cannot get a gadfly CG for annotated gene ".$gene->cg.".") and next
                            unless $g;
         $fbgn = $g->flybase_accession_no;
         $fbgn = $fbgn->acc_no if $fbgn;
      }
      $session->warn($gene->cg." does not have an accession number") and next unless $fbgn;

      push @geneHits, {name=>$gene->cg,
                       arm=>$g->arm,
                       start=>$g->start,
                       transcript=>$gene->transcript,
                       fbgn => $fbgn,
                       end=>$g->end,
                       comment=>($gene->comment || 'Manual curation to release 3.1 annotations') };
   }

   $gadflyDba->close;
   return @geneHits;

}

sub getGeneHit
{
   my $session = shift;

   # where are we hitting?
   my $arm = shift;
   my $strand = shift;
   my @pos = @_;

   my $grabSize = 0;
   my $gadflyDba;
  
   my $geneXML;
   my $geneName;
   # either WithinGene, WithinTranscript or WithinCDS
   my $geneHit;

   my $geneFbgn;

   $ENV{GADB_SUPPRESS_RESIDUES} = 1;

   $session->log($Session::Info,
                      "Looking at hit on $arm at position range @pos.");

   if (grep(/$arm$/,qw(2L 2R 3L 3R 4 X)) ) {
      # euchromatic release 3 arm
      $gadflyDba = GxAdapters::ConnectionManager->get_adapter("gadflyi");
   } else {
      # unmapped heterchromatic or shotgun arm extension
      $gadflyDba = GxAdapters::ConnectionManager->get_adapter("gadflyi");
      $arm = 'X.wgs3_centromere_extensionB'
                              if $arm eq 'X.wgs3_centromere_extension';
   }

   my $start = $pos[0] - $grabSize;
   $start = ($start<0)?0:$start;
   my $end =  $pos[-1] + $grabSize;

   my $seqs = $gadflyDba->get_AnnotatedSeq(
                {range=>"$arm:$start..$end",type=>'gene'},['-results']);
   my @annot = $seqs->annotation_list()?@{$seqs->annotation_list}:();
   $session->log($Session::Info,"Found ".scalar(@annot).
                                   " genes within $grabSize.");

   # look at each annotation and decide if we're inside it.

   my @geneNameList = ();
   my @geneHitList = ();
   my @geneFbgnList = ();
   my @geneRelList = ();
   my @geneDist5List = ();
   my @geneDist3List = ();
   foreach my $annot (@annot) {
       next unless $annot->gene;
       my $gene = $annot->gene;
       $session->log($Session::Info,
                "Nearby gene ".$gene->name()." from ".
                ($start+$gene->start())." to ".  ($start+$gene->end)); 
       my ($gStart,$gEnd) = sort {$a <=> $b} ($gene->start,$gene->end);
 
       if ( $pos[0] >= $start+$gStart && $pos[1] <= $start+$gEnd ) {
          # if this isn't a real gene, we gotta skip it
          next unless $gene->flybase_accession_no;
          next unless $gene->name =~ /^CG\d+$/;
          push @geneNameList, $gene->name;
          push @geneHitList, 'WithinGene';
          push @geneFbgnList, $gene->flybase_accession_no->acc_no;
          push @geneRelList, (($strand>0 && $gene->end>$gene->start)||
                              ($strand<0 && $gene->end<$gene->start))?'p':'m';

       #  # we need this for the real coordinates
       #  my $g = $gadflyDba->get_Gene({name=>$gene->name});
       #  my @pos_to_5 = @pos;
       #  map { $_ = abs($_ - $g->start) } @pos_to_5;
       #  push @geneDist5List, (sort {$a <=> $b} @pos_to_5)[0];
       #  my @pos_to_3 = @pos;
       #  map { $_ = abs($_ - $g->end) } @pos_to_3;
       #  push @geneDist3List, (sort {$a <=> $b} @pos_to_3)[0];
          
          $session->log($Session::Info, "Hit ".$gene->name." (".$gene->flybase_accession_no->acc_no.").");
          # TODO: now see if we're within a Transcript....within a CDS
       }
   }
   $gadflyDba->close;

   # combine the results into a list of XML::Within* objects; 
   my @results = ();
   while (@geneHitList) {
      my $which = shift @geneHitList;
      my $args = {rel_orientation => shift @geneRelList,
          #        distance_to_transcript_5 => shift @geneDist5List,
          #        distance_to_transcript_3 => shift @geneDist3List
                  };
                  
      my $geneXML;
      if ($which eq 'WithinGene') {
         $geneXML = new XML::WithinGene($args);
      } elsif ($which eq 'WithinTranscript') {
         $geneXML = new XML::WithinTranscript($args);
      } elsif ($which eq 'WithinCDS') {
         $geneXML = new XML::WithinCDS($args);
      } else {
         $session->error('Inconsistent switch',"Cannot determine type of hit.");
      }
      my $localGene = new XML::LocalGene({fbgn=>shift @geneFbgnList,
                                     cg_number=>shift @geneNameList
                                   });
      $geneXML->add($localGene);
      push @results,$geneXML;
   }

   return @results;
  
}
