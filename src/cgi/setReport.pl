#!/usr/local/bin/perl -I../modules

=head1 NAME

  setReport.pl Web report of the alignment status for a set of strains

=cut

use Pelement;
use Session;
use Seq;
use SeqSet;
use Sample;
use SampleSet;
use Strain;
use Seq_AlignmentSet;
use Seq_Alignment;
use Phenotype;
use Submitted_Seq;
use Lane;
use LaneSet;
use Cytology;
use PelementCGI;
use PelementDBI;

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

use strict;

my $cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>"Strain Set Alignment Report"});
print $cgi->banner();

my $action = $cgi->param('action');

if ( $action eq 'Add') {
   addStrains($cgi);
   selectSet($cgi);
} elsif ($action eq 'Read') {
   loadFile($cgi);
   selectSet($cgi);
} elsif ($action eq 'Report' && $cgi->param('strain')) {
   my @strain = $cgi->param('strain');
   reportSet($cgi);
} else {
   selectSet($cgi);
}

print $cgi->footer([
                 {link=>"batchReport.pl",name=>"Batch Report"},
                 {link=>"strainReport.pl",name=>"Strain Report"},
                 {link=>"gelReport.pl",name=>"Gel Report"},
                 {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                  ]);
print $cgi->close_page();

exit(0);

sub loadFile
{
   my $cgi = shift;

   my $uploaded;
   # there may have been a file to read;
   if ($cgi->param('upfile') ) {
      my $fn = $cgi->param('upfile');
      my $fh = $cgi->upload($fn);

      print "DEBUG: file handle is $fh corresponding to upfile ".$cgi->param('upfile')."<br>\n";
      foreach my $k (keys %{$cgi->{'.tmpfiles'}}) {
         print "DEBUG: what is this: ".join(' ',%{$cgi->{'.tmpfiles'}->{$k}})."<br>\n";
         print "DEBUG: what is this: ".join(' ',%{$cgi->{'.tmpfiles'}->{$k}->{'info'}})."<br>\n";
      }
      my @lines = <$fh>;

      map { print "DEBUG: Read line $_<br>\n" } @lines;
   }
}

sub addStrains
{
   my $cgi = shift;

   # look for a batch number
   my @batchN;
   return unless @batchN = $cgi->param('batch');

   # join and re-split
   @batchN = split(/[\s,]/,join(' ',@batchN));
  
   my $session = new Session({-log_level=>0});

   foreach my $batchN (@batchN) {
      next unless $batchN =~ /^\d+$/;

      my $sS = new SampleSet($session,{-batch_id=>$batchN})->select;
      my $sList;
      map { $sList .= ' '.$_->strain_name } $sS->as_list;
      $cgi->param('strain',$cgi->param('strain').$sList);
   }

   $session->exit;
   $cgi->delete('batch');
   return;
}

sub selectSet
{

   my $cgi = shift;

   my $loaded; 

   my $COLS = 40;

   # look though the list of strains, sort, remove duplicates and
   # reformat

   my @strains;
   map { push @strains,split(/\s/,$_) } $cgi->param('strain');
   my %stHash;

   map { $stHash{$_}=1 } @strains;
   @strains = sort {$a cmp $b} keys %stHash;
   
   while (@strains) {
      my $next = shift @strains;
      if ($loaded) {
         if (int( (length($loaded)+length($next))/$COLS ) != int( (length($loaded)-1)/$COLS) ) {
            $loaded .= "\n";
         } else {
            $loaded .= " ";
         }
      }
      $loaded .= $next;
   }

   $cgi->delete('strain');
   $cgi->param('strain',$loaded);


   # nothing is given. present a form to type into.
   print
     $cgi->center(
       $cgi->h3("Enter the Strain identifiers, separated by spaces or commas:"),"\n",
       $cgi->start_form(-method=>"get",-action=>"setReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
              $cgi->td({-colspan=>2,-align=>'center'},
                    [$cgi->textarea(-name=>'strain',-cols=>$COLS,-rows=>20)]),
              # this dont work
              #$cgi->td({-colspan=>2,-align=>'center'},['Upload a text file of strains names: <b> this is not working yet.</b>']),
              #$cgi->td([$cgi->filefield('upfile'),$cgi->submit(-name=>'action',-value=>'Read')]),
              $cgi->td({-colspan=>2,-align=>'center'},['Include strains from the batch(s):']),
              $cgi->td([$cgi->textfield(-name=>'batch'),$cgi->submit(-name=>'action',-value=>'Add')]),
              $cgi->td({-colspan=>2,-align=>'center'},[$cgi->h3('Reports to view:')]),
              $cgi->td([$cgi->checkbox(-name=>'view',-label=>'Uniquely Aligned Sequences',-value=>'align',-checked=>1),
                        $cgi->checkbox(-name=>'view',-label=>'Unaligned Sequences',-value=>'unalign',-checked=>1)]),
              $cgi->td([$cgi->checkbox(-name=>'view',-label=>'Multiply Aligned Sequences',-value=>'multiple',-checked=>1),
                        $cgi->checkbox(-name=>'view',-label=>'Missing Sequences',-value=>'bad',-checked=>1)]),
              $cgi->td([$cgi->checkbox(-name=>'view',-label=>'Merged Sequences',-value=>'merged',-checked=>1),
                        $cgi->checkbox(-name=>'view',-label=>'Stock Center Submission',-value=>'stock')]),
              $cgi->td([$cgi->checkbox(-name=>'view',-label=>'Fasta Sequences',-value=>'fasta')]),
              $cgi->td({-align=>'center'},
                  [$cgi->submit(-name=>'action',-value=>'Report'),$cgi->reset(-name=>'Reset')]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub reportSet
{
   my $cgi = shift;

   my @set = $cgi->param('strain');

   my $session = new Session({-log_level=>0});

   my @goodHits = ();
   my @multipleHits = ();
   my @unalignedSeq = ();
   my @badStrains = ();
   my @mergedStrains = ();
   my $fastaSeq;

   my %reports;
   my @reports = $cgi->param('view');
   map { $reports{$_}=1 } @reports;

   # filter the set list to eliminate redundancies, end identiers, punctuation,,

   my %seqSet = ();
   map { map {$seqSet{Seq::strain($_)}=1 unless !$_ || $_ =~ /[,+]/ } split(/\s/,$_) } @set;

   foreach my $strain (sort keys %seqSet) {

      my $strainLink = $cgi->a(
                 {-href=>"strainReport.pl?strain=".$strain,
                  -target=>"_strain"}, $strain);
      my $seqS = new SeqSet($session,{-strain_name=>$strain})->select;
      if (!$seqS->as_list) {
         push @badStrains, [$strain];
         next;
      }

      foreach my $seq ($seqS->as_list) {
         # keep track of the fasta seq if desired.
         if ($reports{fasta}) {
           $fastaSeq .= '>'.$seq->seq_name;
           my $sub = new Submitted_Seq($session,{-seq_name=>$seq->seq_name});
           if ($sub->db_exists) {
              $sub->select;
              $fastaSeq .= ' '.$sub->gb_acc;
           }
           $fastaSeq .= ' [insertion position '.$seq->insertion_pos.']' if $seq->insertion_pos;
           $fastaSeq .= "\n";
           my $s = $seq->sequence;
           $s =~ s/(.{50})/$1\n/g;
           $fastaSeq .= $s ."\n";
         }
         if ($seq->end eq 'b') {
            push @mergedStrains, [$strainLink];
            next;
         }
         my $seqAS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;
         if (!scalar($seqAS->as_list)) {
            push @unalignedSeq , [$strainLink,$seq->seq_name,length($seq->sequence)];
            next;
         }

         # we'll go through this list looking for things other than muliples or deselected
         my $gotAHit = 0;
         foreach my $seqA ($seqAS->as_list) {
            if ($seqA->status ne 'multiple' && $seqA->status ne 'deselected' ) {
               if ( $gotAHit ) {
                  push @goodHits,
                       [$strainLink,$seq->seq_name,$seqA->scaffold,$seqA->s_insert,
                             ($seqA->p_end>$seqA->p_start)?'Plus':'Minus',$seqA->status." TROUBLE"];
               } else {
                  $gotAHit = 1;
                  (my $arm = $seqA->scaffold) =~ s/arm_//;
                  push @goodHits,
                       [$strainLink,$seq->seq_name,$arm,$seqA->s_insert,
                             ($seqA->p_end>$seqA->p_start)?'Plus':'Minus',$seqA->status];
               }
            }
         }

         push @multipleHits ,[$strainLink,$seq->seq_name] if !$gotAHit;
      }
   }

   if ( $reports{'align'} ) {
      if ( @goodHits ) {
         @goodHits = sort { $a->[1] cmp $b->[1] } @goodHits;
         print $cgi->center($cgi->h3("Sequence Alignments"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
              $cgi->Tr( [
                 $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                         ["Strain","Sequence<br>Name","Scaffold",
                          "Location","Strand","Status"] ),
                              (map { $cgi->td({-align=>"center"}, $_ ) } @goodHits),
                          ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      } else {
         print $cgi->center($cgi->h3("No Sequence Alignments for this set."),$cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ($reports{'unalign'} ) {
      if (@unalignedSeq) {
         @unalignedSeq = sort { $b->[2] <=> $a->[2] } @unalignedSeq;
         print $cgi->center($cgi->h3("Unaligned Sequences"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
              $cgi->Tr( [
                 $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                         ["Strain","Sequence<br>Name","Sequence<br>Length"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) } @unalignedSeq),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      } else {
         print $cgi->center($cgi->h3("No Unaligned Sequences for this set."),$cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ( $reports{'multiple'} ) {
      if ( @multipleHits ) {

         @multipleHits = sort { $a->[1] cmp $b->[1] } @multipleHits;
         print $cgi->center($cgi->h3("Sequences With Multiple Hits"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"50%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
              $cgi->Tr( [
                 $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                         ["Strain","Sequence<br>Name"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) } @multipleHits),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      
      } else {
         print $cgi->center($cgi->h3("No Multiply Aligned Sequences for this set."),$cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ( $reports{'merged'} ) {
      if ( @mergedStrains ) {

         @mergedStrains = sort { $a->[0] cmp $b->[0] } @mergedStrains;
         print $cgi->center($cgi->h3("Merged Flanking Sequences"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"30%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
              $cgi->Tr( [
                 $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                         ["Strain"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) } @mergedStrains),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      
      } else {
         print $cgi->center($cgi->h3("No Merged Flanking Sequences for this set."),$cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ( $reports{'bad'} && @badStrains ) {
      @badStrains = sort { $a->[0] cmp $b->[0] } @badStrains;
      print $cgi->center($cgi->h3("Strains not in the DB"),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,-width=>"30%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @badStrains),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
   }
 
   my $setLink = join('+',@set);
   $setLink =~ s/\s+/+/g;
   map { $setLink .= "&view=$_" } keys %reports;

   my @stockList;
   if ($reports{'stock'} && (@stockList = generateStockList($session,\%seqSet)) ) {
      # replace null strings with nbsp's
      map { map { $_ = $_?$_:$cgi->nbsp } @$_ } @stockList;
      print $cgi->center($cgi->h3("Stock List"),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain","Arm","Range","Cytology","Gene(s)"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @stockList),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'50%'}),"\n";
   }

   if ($reports{'fasta'}) {
      print $cgi->center($cgi->h3("Fasta"),$cgi->br),"\n";
      $fastaSeq =~ s/\n\n/\n/gs;
      print $cgi->pre($fastaSeq);
   }

   print $cgi->br,
         $cgi->html_only($cgi->a({-href=>"setReport.pl?action=Report&strain=$setLink&format=text"},
                  "View Report on this set as Tab delimited list."),$cgi->br,"\n"),
         $cgi->html_only($cgi->a({-href=>"setReport.pl?action=Report&strain=$setLink"},
                  "Refresh Report on this set."),$cgi->br,"\n");
  $session->exit();
}

sub generateStockList{

   my ($session,$strainH) = @_;
   my @returnList;

   foreach my $strain (sort keys %$strainH) {

      my $laneSet = new LaneSet($session,{-seq_name=>$strain})->select;
      next unless $laneSet->as_list;

      # default operation if batch was not specified is to consider it a 'pass'

      my @insertList = getCytoAndGene($session,$strain);
      if (scalar(@insertList) ) {
         map {push @returnList, [$strain,$_->{arm},$_->{range},$_->{band},join(" ",@{$_->{gene}})] } @insertList;
      } else {
         push @returnList, [$strain,,,,];
      }
   }

   return @returnList;
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
         next unless $sa->status eq 'unique' || $sa->status eq 'curated';

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
         $cyto = new Cytology($session,{scaffold=>$in->{arm},
                                    less_than=>{start=>$end},
                        greater_than_or_equal=>{stop=>$start}})->select_if_exists;
         $in->{band} = ($cyto && $cyto->band)?$cyto->band:'Het';
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
          next unless $gene->name =~ /^C[GR]\d+$/;
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
