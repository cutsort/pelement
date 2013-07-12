#!/usr/bin/env perl
use FindBin::libs 'base=modules';

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
use StrainSet;
use Seq_AlignmentSet;
use Seq_Alignment;
use PhaseSet;
use Phase;
use Phenotype;
use Submitted_Seq;
use Lane;
use LaneSet;
use Cytology;
use PelementCGI;
use PelementDBI;

use List::MoreUtils qw(uniq);

use strict;
no strict 'refs';

my $cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>"Strain Set Alignment Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
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
} elsif ($action eq 'Format') {
   selectSet($cgi);
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

      print "DEBUG: file handle is $fh corresponding to upfile ".
                                           $cgi->param('upfile')."<br>\n";
      foreach my $k (keys %{$cgi->{'.tmpfiles'}}) {
         print "DEBUG: what is this: ".
                     join(' ',%{$cgi->{'.tmpfiles'}->{$k}})."<br>\n";
         print "DEBUG: what is this: ".
                     join(' ',%{$cgi->{'.tmpfiles'}->{$k}->{'info'}})."<br>\n";
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
         if (int( (length($loaded)+length($next))/$COLS ) !=
                                  int( (length($loaded)-1)/$COLS) ) {
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
      $cgi->h3("Enter the Strain identifiers, separated by spaces or commas:"),
       "\n",
       $cgi->start_form(-method=>"get",-action=>"setReport.pl"),"\n",
          $cgi->table( {-class=>'unboxed'},
             $cgi->Tr( [
              $cgi->td({-colspan=>2,-align=>'center'},
                    [$cgi->textarea(-name=>'strain',-cols=>$COLS,-rows=>20,-id=>'textArea')]),
              $cgi->td({-align=>'center'},
                      [$cgi->submit(-name=>'action',-value=>'Format'),
                       $cgi->nbsp.$cgi->em('"Format" cleans up the').
                         $cgi->br.$cgi->em('list of strain id\'s')]),
              # this dont work
              #$cgi->td({-colspan=>2,-align=>'center'},
              #   ['Upload a text file of strains: <b> not working yet.</b>']),
              #$cgi->td([$cgi->filefield('upfile'),
              #     $cgi->submit(-name=>'action',-value=>'Read')]),
              $cgi->td({-colspan=>2,-align=>'center'},
                      ['Include strains from the batch(s):']),
              $cgi->td([$cgi->textfield(-name=>'batch'),
                     $cgi->submit(-name=>'action',-value=>'Add')]),
              $cgi->td({-colspan=>2,-align=>'center'},
                       [$cgi->h3('Reports to view:')]),
              $cgi->td([$cgi->checkbox(-name=>'view',
              -label=>'Uniquely Aligned Sequences',-value=>'align'),
                        $cgi->checkbox(-name=>'view',
                                       -label=>'Unaligned Sequences',
                                       -value=>'unalign')]),
              $cgi->td([$cgi->checkbox(-name=>'view',
                                       -label=>'Multiply Aligned Sequences',
                                       -value=>'multiple'),
                        $cgi->checkbox(-name=>'view',
                                       -label=>'Missing Sequences',
                                       -value=>'bad')]),
              $cgi->td([$cgi->checkbox(-name=>'view',
                                       -label=>'Merged Sequences',
                                       -value=>'merged'),
                        $cgi->checkbox(-name=>'view',
                                       -label=>'Stock Center Submission',
                                       -value=>'stock')]),
              $cgi->td([$cgi->checkbox(-name=>'view',
                                       -label=>'Position Classifications',
                                       -value=>'class'),
                        $cgi->checkbox(-name=>'view',
                                       -label=>'Intron Phase',
                                       -value=>'intron')]),
              $cgi->td([$cgi->checkbox(-name=>'view',
                                       -label=>'Fasta Sequences',
                                       -value=>'fasta'),
                        ]),
              $cgi->td({-align=>'left'},
                  [$cgi->radio_group(-name => 'release',
                                     -values => ['3','5'],
                                     -labels => {3=>'Use Release 3 Alignments',
                                                 5=>'Use Release 5 Alignments'},
                                     -default =>'5')]),
              $cgi->td({-align=>'center'},
                  [$cgi->submit(-name=>'action',
                                       -value=>'Report'),
                                       $cgi->reset(-name=>'Reset')]) ]
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
   my @stockList = ();
   my $fastaSeq;
   my $release = $cgi->param('release') || '5';

   my %reports;
   my @reports = $cgi->param('view');
   map { $reports{$_}=1 } @reports;

   # so that we don't double report stocks
   my %stockReport = ();
 
   # filter the set list to eliminate redundancies, end identiers, punctuation,,
   my %seqSet = ();
   map { map {$seqSet{Seq::strain($_)}=1 unless !$_ || $_ =~ /[,+]/ }
                                                   split(/\s/,$_) } @set;

   # expand wildcards
   foreach my $strain (sort keys %seqSet) {
      if ($strain =~ /%/) {
         my $xSet = new StrainSet($session,{-like=>{strain_name=>$strain}})->select;
         map { $seqSet{$_->strain_name} = 1 } $xSet->as_list;
         delete $seqSet{$strain};
      }
   }

   foreach my $strain (sort keys %seqSet) {

      my $seqS;
      if ($strain =~ /%/) {
         # wild card search. watch out!
         $seqS = new SeqSet($session,{-like=>{strain_name=>$strain}})->select;
      } else {
         $seqS = $session->SeqSet({-strain_name=>$strain})->select;
         if (!$seqS->as_list) {
            push @badStrains, [$strain];
            next;
         }
      }

      foreach my $seq ($seqS->as_list) {

         my $strainLink = $cgi->a(
                    {-href=>"strainReport.pl?strain=".$seq->strain_name,
                     -target=>"_strain"}, $seq->strain_name);

         # keep track of the fasta seq if desired.
         if ($reports{fasta}) {
           $fastaSeq .= '>'.$seq->seq_name;
           my $sub = new Submitted_Seq($session,{-seq_name=>$seq->seq_name});
           if ($sub->db_exists) {
              $sub->select;
              $fastaSeq .= ' '.$sub->gb_acc;
           }
           $fastaSeq .= ' [insertion position '.$seq->insertion_pos.']'
                                                   if $seq->insertion_pos;
           $fastaSeq .= "\n";
           my $s = $seq->sequence;
           $s =~ s/(.{50})/$1\n/g;
           $fastaSeq .= $s ."\n";
         }

         # check to see if this sequence (or any constituent) is vector
         # trimmed.

         my $trimmed;
         if( $session->Seq_AssemblySet({-seq_name=>$seq->seq_name})->select->count ) {
            # we have some pieces to look at
            $trimmed = determineVTrim($session,$seq->seq_name) || 'No';
         } else {
            $trimmed = 'Untracked';
         }

         # some merged seqs are the basis of alignments; other times
         # they are not
         my $ok_if_unaligned=0;
         if ($seq->end eq 'b') {
            # this is a merged sequence only if it is a result of a
            # assembly from other seqs;
            my $sa = $session->Seq_AssemblySet({-seq_name=>$seq->seq_name,src_seq_src=>'seq'})->select;
            if ($sa->count) {
              push @mergedStrains, [$strainLink];
              $ok_if_unaligned = 1;
            }
         }
         my $seqAS = new Seq_AlignmentSet($session,
                                      {-seq_name=>$seq->seq_name,
                                       -seq_release=>$release})->select;   # for now
         if (!scalar($seqAS->as_list)) {
            push @unalignedSeq ,
                        [$strainLink,$seq->seq_name,length($seq->sequence),$trimmed]
                        unless $ok_if_unaligned;
         }


         # we'll go through this list looking for things other
         # than muliples or deselected
         my $gotAHit = 0;
         my $gotAMulti = 0;
         foreach my $seqA ($seqAS->as_list) {
            if ($seqA->status ne 'multiple' && $seqA->status ne 'deselected' ) {
               if ( $gotAHit ) {
                  push @goodHits,
                       [$strainLink,$seq->seq_name,$seqA->scaffold,
                                                 $seqA->s_insert,
                       ($seqA->p_end>$seqA->p_start)?'Plus':'Minus',
                                             $seqA->status." TROUBLE",$trimmed];
               } else {
                  $gotAHit = 1;
                  (my $arm = $seqA->scaffold) =~ s/arm_//;
                  push @goodHits,
                       [$strainLink,$seq->seq_name,$arm,$seqA->s_insert,
                             ($seqA->p_end>$seqA->p_start)?'Plus':'Minus',
                                             $seqA->status,$trimmed];
               }
            } elsif ($seqA->status eq 'multiple') {
              $gotAMulti = 1;
            }
         }

         push @multipleHits ,[$strainLink,$seq->seq_name,$trimmed] if !$gotAHit && $gotAMulti;

         push @stockList,generateStockList($session,$seq->strain_name,$release)
                     if $reports{'stock'} && !$stockReport{$seq->strain_name}; 
         $stockReport{$seq->strain_name} = 1;
      }
   }

   if ( $reports{'align'} ) {
      if ( @goodHits ) {
         @goodHits = sort { $a->[1] cmp $b->[1] } @goodHits;
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"Sequence Alignments (Release $release)"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"80%",
                                     -class=>'sortable',
                                     -id=>'good_hits'},
              $cgi->Tr( [
                 $cgi->th(
                         ["Strain","Sequence Name","Scaffold",
                          "Location","Strand","Status",'Vector Trimmed'] ),
                              (map { $cgi->td({-align=>"center"}, $_ ) }
                                                               @goodHits),
                          ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      } else {
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"No Sequence Alignments for this set."),
               $cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ($reports{'unalign'} ) {
      if (@unalignedSeq) {
         @unalignedSeq = sort { $b->[2] <=> $a->[2] } @unalignedSeq;
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"Unaligned Sequences (Release $release)"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"80%",
                                     -class=>'sortable',
                                     -id=>'unaligned_hits'},
              $cgi->Tr( [
                 $cgi->th(
                         ["Strain","Sequence Name","Sequence Length","Vector Trimmed"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) }
                                                             @unalignedSeq),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      } else {
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"No Unaligned Sequences for this set."),
                                     $cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ( $reports{'multiple'} ) {
      if ( @multipleHits ) {

         @multipleHits = sort { $a->[1] cmp $b->[1] } @multipleHits;
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"Sequences With Multiple Hits (Release $release)"),$cgi->br),
            "\n",
            $cgi->center($cgi->table({-border=>2,-width=>"50%",
                                      -class=>'sortable',
                                      -id=>'multiple_hits'},
              $cgi->Tr( [
                 $cgi->th(
                         ["Strain","Sequence Name","Vector Trimmed"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) }
                                    @multipleHits), ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      
      } else {
         print $cgi->center(
               $cgi->div({-class=>'SectionTitle'},"No Multiply Aligned Sequences for this set."),
                              $cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ( $reports{'merged'} ) {
      if ( @mergedStrains ) {

         @mergedStrains = sort { $a->[0] cmp $b->[0] } @mergedStrains;
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"Merged Flanking Sequences"),$cgi->br),"\n",
            $cgi->center(
              $cgi->table({-border=>2,-width=>"30%",
                                      -class=>'sortable',
                                      -id=>'merged'},
              $cgi->Tr( [
                 $cgi->th(
                         ["Strain"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) }
                                                 @mergedStrains),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
      
      } else {
         print $cgi->center(
               $cgi->div({-class=>'SectionTitle'},"No Merged Flanking Sequences for this set."),
                            $cgi->br),$cgi->hr({-width=>'70%'}),"\n",
      }
   }

   if ($reports{'intron'}) {
         my @phases;
         map {push @phases ,[$_,intronPhase($session,$_,$release)] } map {split /\s+/,$_} sort keys %seqSet;
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"Intron Phase"),$cgi->br),"\n",
            $cgi->center(
              $cgi->table({-border=>2,-width=>"30%",
                                      -class=>'sortable',
                                      -id=>'merged'},
              $cgi->Tr( [
                 $cgi->th(
                         ["Strain","Phase"] ),
                          (map { $cgi->td({-align=>"center"}, $_ ) }
                                                 @phases),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";

   }

   if ($reports{'class'}) {
       my @classes;
       map { push @classes, [$_,classifyInsert($cgi,$session,$_,$release)] }  map {split /\s+/,$_} sort keys %seqSet;
         print $cgi->center($cgi->div({-class=>'SectionTitle'},"Position Classification"),$cgi->br),"\n",
            $cgi->center(
              $cgi->table({-border=>2,-width=>"80%",
                                      -class=>'sortable',
                                      -id=>'merged'},
              $cgi->Tr( [
                 $cgi->th(
                         ["Strain","Coding Exon","5' UTR Exon","3' UTR Exon","Coding Intron",
                          "5' UTR Intron","3' UTR Intron","5' Upstream","3' Downstream"] ),
                          (map { scalar(@$_)>2?$cgi->td({-align=>"center"}, $_ ):
                            $cgi->td({-align=>"center"},[$_->[0]]).$cgi->td({-align=>"center",-colspan=>"8"},[$_->[1]]) } @classes),
                         ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";

   }
     

   if ( $reports{'bad'} && @badStrains ) {
      @badStrains = sort { $a->[0] cmp $b->[0] } @badStrains;
      print $cgi->center($cgi->div({-class=>'SectionTitle'},"Strains not in the DB"),$cgi->br),"\n",
         $cgi->center(
           $cgi->table({-border=>2,-width=>"30%",
                                      -class=>'sortable',
                                      -id=>'bad'},
           $cgi->Tr( [
              $cgi->th(
                      ["Strain"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @badStrains),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
   }
 
   my $setLink = join('+',@set);
   $setLink =~ s/\s+/+/g;
   map { $setLink .= "&view=$_" } keys %reports;

   if ($reports{'stock'} ) {
      # replace null strings with nbsp's
      map { map { $_ = $_?$_:$cgi->nbsp } @$_ } @stockList;
      print $cgi->center($cgi->div({-class=>'SectionTitle'},"Stock List (R$release Coords, R5.3 Genes)"),$cgi->br),"\n",
         $cgi->center(
           $cgi->table({-border=>2,-width=>"80%",
                                      -class=>'sortable',
                                      -id=>'stock'},
           $cgi->Tr( [
              $cgi->th(
                      ["Strain","Arm","Range","Strand","Cytology","Gene(s)"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @stockList),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'50%'}),"\n";
   }

   if ($reports{'fasta'}) {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},"Fasta"),$cgi->br),"\n";
      $fastaSeq =~ s/\n\n/\n/gs;
      print $cgi->pre($fastaSeq);
   }

   print $cgi->br,
         $cgi->html_only($cgi->a(
             {-href=>"setReport.pl?action=Report&strain=$setLink&format=text&release=$release"},
              "View Report on this set as Tab delimited list."),$cgi->br,"\n"),
         $cgi->html_only($cgi->a(
             {-href=>"setReport.pl?action=Report&strain=$setLink&release=$release"},
              "Refresh Report on this set."),$cgi->br,"\n");
  $session->exit();
}

sub generateStockList
{

   my ($session,$strain,$release) = @_;
   my @returnList;

   # default operation if batch was not specified is to consider it a 'pass'

   my @insertList = getCytoAndGene($session,$strain,$release);
   if (scalar(@insertList) ) {
      map {push @returnList, [$strain,$_->{arm},$_->{range},$_->{strand},$_->{band},
                                  join(" ",@{$_->{gene}})] } @insertList;
   } else {
      push @returnList, [$strain,,,,];
   }

   return @returnList;
}

sub getCytoAndGene
{
   my $session = shift;
   my $strain = shift;
   my $release = shift;

   # we need to look at the alignments for the unqualified sequences.
   # and look for if we have the mappable insertions.
   my @insertList = ();
   my $seqList = new SeqSet($session,{-strain_name=>$strain})->select;
   foreach my $seq ($seqList->as_list) {
      next if $seq->qualifier;
      my $saS = new Seq_AlignmentSet($session,
                                   {-seq_name=>$seq->seq_name,
                                    -seq_release=>$release})->select;
      foreach my $sa ($saS->as_list) {
         next unless $sa->status eq 'unique' || $sa->status eq 'curated';

         # keep track of release 4 number
         my $cyto_base = $sa->s_insert;

         my $isNewInsertion = 1;
         foreach my $in (@insertList) {
           if ($in->{arm} eq $sa->scaffold &&
                                   closeEnuf($in->{range},$sa->s_insert)) {
              $in->{range} = mergeRange($in->{range},$sa->s_insert);
              $isNewInsertion = 0;
              last;
           }
         }
         if ($isNewInsertion) {
            push @insertList, {arm   => $sa->scaffold,
                               range => $sa->s_insert.":".$sa->s_insert,
                               strand => ($sa->p_start > $sa->p_end)?-1:1,
                               band  => '',
                               gene  => [] };
         }
      }
   }

   foreach my $in (@insertList) {
      my ($start,$end) = split(/:/,$in->{range});
      my $arm = $in->{arm};
      my $cyto;
      if ($arm =~ s/arm_// ) {
         $cyto = new Cytology($session,{scaffold=>$in->{arm},
                                    less_than=>{start=>$end},
                                    -seq_release=>$release,
                    greater_than_or_equal=>{stop=>$start}})->select_if_exists;
         $in->{band} = $cyto->band;
         $in->{arm} =~ s/arm_//;
      } else {
         $cyto = new Cytology($session,{scaffold=>$in->{arm},
                                    less_than=>{start=>$end},
                                    -seq_release=>$release,
                    greater_than_or_equal=>{stop=>$start}})->select_if_exists;
         $in->{band} = ($cyto && $cyto->band)?$cyto->band:'Het';
      }

      my @annot = ();

      my $down = $in->{strand}==1?0:500;
      my $up = $in->{strand}==1?500:0;
 
      my $down = $in->{strand}==1?0:0;
      my $up = $in->{strand}==1?0:0;

      my @geneSet = map {$_->gene_name, $_->gene_uniquename, $_->gene_start, $_->gene_end}
        $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -less_than_or_equal=>{gene_start=>$end+$up},
          -greater_than_or_equal=>{gene_end=>$start-$down},
          -rtree_bin=>{gene_bin=>[$end+$up, $start-$down]},
        })->select->as_list;

      # look at each annotation and decide if we're inside it.

      my %gene_name_hash;
      while (@geneSet) {
        my $gene_name = shift @geneSet;
        my $gene_uniquename = shift @geneSet;
        my $gene_start = shift @geneSet;
        my $gene_end = shift @geneSet;
        # we need to see if we're really within the gene or nearby
        #if( $start <= $annot->gene_end && $end >= $annot->gene_start) {
        if( $start <= $gene_end && $end >= $gene_start) {
           #$gene_name_hash{$annot->gene_name.'('.$annot->gene_uniquename.')'} = 1;
           $gene_name_hash{$gene_name.'('.$gene_uniquename.')'} = 1;
        #} elsif ( !exists( $gene_name_hash{$annot->gene_name.'('.$annot->gene_uniquename.')'}) ) {
        } elsif ( !exists( $gene_name_hash{$gene_name.'('.$gene_uniquename.')'}) ) {
           #$gene_name_hash{$annot->gene_name.'('.$annot->gene_uniquename.')'} = 'near';
           $gene_name_hash{$gene_name.'('.$gene_uniquename.')'} = 'near';
        }
           
      }
      map { push @{$in->{gene}}, $_.(($gene_name_hash{$_} eq 'near')?'[near]':'') } sort keys %gene_name_hash;
   }

   # if possible, we'll update the phenotype/genotype list
   #if (scalar(@insertList) == 1) {
   #   my $pheno = new Phenotype($session,{-strain_name=>$strain}
   #                                              )->select_if_exists;
   #   my $in = $insertList[0];
   #   if ($in->{band} && !$pheno->derived_cytology) {
   #      $pheno->derived_cytology($in->{band});
   #      if ($pheno->id) {
   #         $pheno->update;
   #      } else {
   #         $pheno->insert;
   #      }
   #   }
   #}
   return @insertList;

}

sub classifyInsert
{
  my $cgi = shift;
  my $session = shift;
  my $strain = shift;
  my $release = shift;

  my $seqS = new SeqSet($session,{-strain_name=>$strain})->select;

  return ('No Sequence Records') unless $seqS->count;

  my $pos;
  my $arm;
  my %byPosition;
  foreach my $seq ($seqS->as_list) {
    next if $seq->qualifier;
    my $aS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name,
                                            -seq_release=>$release});
    $aS->select;
    foreach my $alignment ($aS->as_list) {
      if ($alignment->status eq 'unique' || $alignment->status eq 'curated') {
        $pos = $alignment->s_insert;
        $arm = $alignment->scaffold;
        $byPosition{$arm.':'.$pos} = 1;
      }
    }
  }
  return ('No Unique or Curated Alignments') unless keys %byPosition;

  return classifyPosition($cgi,$session,keys %byPosition);

}

sub classifyPosition
{
  my $cgi = shift;
  my $session = shift;
  my @locs = @_;

  my %return;

  my $upstream = 500;
  my %resultsHash;

  my @transcript_type_ids = (475,438,368,450,456,461,426,927);
  
  foreach my $location (@locs) {
    my ($arm,$pos) = split(/:/,$location);
    $arm =~ s/arm_//;
    my @vals;

    push @{$resultsHash{coding_class}}, uniq map {$_->transcript_name}
      $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than_or_equal=>{exon_end=>$pos, cds_max=>$pos},
          -less_than_or_equal=>{exon_start=>$pos, cds_min=>$pos},
          -rtree_bin=>{exon_bin=>[$pos, $pos], cds_bin=>[$pos, $pos]},
        })->select->as_list;
      
    push @{$resultsHash{utr_5exon_class}}, uniq map {$_->transcript_name}
      grep {($_->cds_min > $pos && $_->exon_strand > 0)
              || ($_->cds_max < $pos && $_->exon_strand < 0)} 
      $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than_or_equal=>{exon_end=>$pos},
          -less_than_or_equal=>{exon_start=>$pos},
          -rtree_bin=>{exon_bin=>[$pos, $pos]},
        })->select->as_list;
        
    push @{$resultsHash{utr_3exon_class}}, uniq map {$_->transcript_name}
      grep {($_->cds_min > $pos && $_->exon_strand < 0)
              || ($_->cds_max < $pos && $_->exon_strand > 0)} 
      $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than_or_equal=>{exon_end=>$pos},
          -less_than_or_equal=>{exon_start=>$pos},
          -rtree_bin=>{exon_bin=>[$pos, $pos]},
        })->select->as_list;
        
    push @{$resultsHash{coding_intron_class}}, uniq map {$_->transcript_name}
      $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than_or_equal=>{cds_max=>$pos},
          -less_than_or_equal=>{cds_min=>$pos},
          -rtree_bin=>{cds_bin=>[$pos, $pos]},
        })->select->as_list;
        
    push @{$resultsHash{utr_5intron_class}}, uniq map {$_->transcript_name}
      grep {($_->cds_min > $pos && $_->transcript_strand > 0)
              || ($_->cds_max < $pos && $_->transcript_strand < 0)}
      $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than_or_equal=>{transcript_end=>$pos},
          -less_than_or_equal=>{transcript_start=>$pos},
          -rtree_bin=>{transcript_bin=>[$pos, $pos]},
        })->select->as_list;
        
    push @{$resultsHash{utr_3intron_class}}, uniq map {$_->transcript_name}
      grep {($_->cds_min > $pos && $_->transcript_strand < 0)
              || ($_->cds_max < $pos && $_->transcript_strand > 0)}
      $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than_or_equal=>{transcript_end=>$pos},
          -less_than_or_equal=>{transcript_start=>$pos},
          -rtree_bin=>{transcript_bin=>[$pos, $pos]},
        })->select->as_list;
        
    push @{$resultsHash{upstream5_class}}, uniq map {$_->transcript_name}
      ($session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than=>{transcript_strand=>0},
          -greater_than_or_equal=>{transcript_start=>$pos},
          -less_than_or_equal=>{transcript_start=>$pos+$upstream},
          -rtree_bin=>{transcript_bin=>[$pos, $pos+$upstream]},
        })->select->as_list,
       $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -less_than=>{transcript_strand=>0},
          -greater_than_or_equal=>{transcript_end=>$pos-$upstream},
          -less_than_or_equal=>{transcript_end=>$pos},
          -rtree_bin=>{transcript_bin=>[$pos-$upstream, $pos]},
        })->select->as_list);
        
    push @{$resultsHash{downstream3_class}}, uniq map {$_->transcript_name}
      ($session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -greater_than=>{transcript_strand=>0},
          -greater_than_or_equal=>{transcript_end=>$pos-$upstream},
          -less_than_or_equal=>{transcript_end=>$pos},
          -rtree_bin=>{transcript_bin=>[$pos-$upstream, $pos]},
        })->select->as_list,
       $session->Gene_ModelSet({
          scaffold_uniquename=>$arm,
          -in=>{transcript_type_id=>\@transcript_type_ids},
          -less_than=>{transcript_strand=>0},
          -greater_than_or_equal=>{transcript_start=>$pos},
          -less_than_or_equal=>{transcript_start=>$pos+$upstream},
          -rtree_bin=>{transcript_bin=>[$pos, $pos+$upstream]},
        })->select->as_list);
  }

  # hashify
  my %bigHash;
  my (%coding_class,%utr_5exon_class,%utr_3exon_class,
      %coding_intron_class,%utr_5intron_class,%utr_3intron_class,
      %upstream5_class,%downstream3_class);

  foreach my $table (qw (coding_class utr_5exon_class utr_3exon_class
                      coding_intron_class utr_5intron_class
                      utr_3intron_class upstream5_class downstream3_class)) {
    map { $bigHash{$table}->{$_} =1 } @{$resultsHash{$table}};
    # now remove a transcript from this class if it appeared in any
    # earlier class;
    foreach my $prev_table (qw (coding_class utr_5exon_class utr_3exon_class
                               coding_intron_class utr_5intron_class
                               utr_3intron_class upstream5_class downstream3_class)) {
      last if $prev_table eq $table;
      map { delete $bigHash{$table}->{$_} if exists $bigHash{$prev_table}->{$_} } keys %{$bigHash{$table}};
    }
    @{$resultsHash{$table}} = sort { $a cmp $b } keys %{$bigHash{$table}};
  }

  return (join_it(@{$resultsHash{coding_class}}),
          join_it(@{$resultsHash{utr_5exon_class}}),
          join_it(@{$resultsHash{utr_3exon_class}}),
          join_it(@{$resultsHash{coding_intron_class}}),
          join_it(@{$resultsHash{utr_5intron_class}}),
          join_it(@{$resultsHash{utr_3intron_class}}),
          join_it(@{$resultsHash{upstream5_class}}),
          join_it(@{$resultsHash{downstream3_class}}));

  sub join_it{ my %hash;
               map { s/-R.$//;
                     $hash{$_} = 1;
                   } @_;
                   return join(' ',sort { $a cmp $b} keys %hash) || $cgi->nbsp }
}

sub intronPhase
{
  my $session = shift;
  my $strain = shift;
  my $release = shift;

  my $seqS = new SeqSet($session,{-strain_name=>$strain})->select;
  return "N/A" unless $seqS->count;
  my $pos;
  my $arm;
  # hashed by transcript
  my %byTranscript;
  my %byPosition;
  foreach my $seq ($seqS->as_list) {
    next if $seq->qualifier;
    my $aS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name,
                                            -seq_release=>$release});
    $aS->select;
    foreach my $alignment ($aS->as_list) {
      if ($alignment->status eq 'unique' || $alignment->status eq 'curated') {
        $pos = $alignment->s_insert;
        $arm = $alignment->scaffold;
        $byPosition{$arm.':'.$pos} = 1;
        my $phaseS = new PhaseSet($session,{-arm=>$arm,-less_than_or_equal=>{intron_start=>$pos},
                                                 -greater_than_or_equal=>{intron_end=>$pos}})->select;
        foreach my $phase ($phaseS->as_list) {
          if (exists($byTranscript{$phase->transcript_name}) ) {
            $byTranscript{$phase->transcript_name} = 'Multiple' if
                     $byTranscript{$phase->transcript_name} ne $phase->phase;
          } else {
            $byTranscript{$phase->transcript_name} = $phase->phase;
          }
        }
      }
    }
  }

  return 'None' unless keys(%byTranscript);

  return join(", ",map { $_.':'.$byTranscript{$_} } sort keys %byTranscript);

}

sub closeEnuf
{
  my $range = shift;
  my $point = shift;
  my ($a,$b) = split(/:/,$range);
  return unless $point =~ /^\d+$/ && $a =~ /^\d+$/ && $b =~ /^\d+$/;
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

=head1 determineVTrim

  Given a seq_name, walk down the list of constituents and track down to the
  phred_seq, then see if the phred seq is vector trimmed.

=cut 

sub determineVTrim
{
  my $s = shift;
  my $seq = shift;
  my $parts = $s->Seq_AssemblySet({-seq_name=>$seq})->select;
  return unless $parts->count;
  foreach my $p ($parts->as_list) {
    if ($p->src_seq_src eq 'phred_seq') {
      my $ph = $s->Phred_Seq({-id=>$p->src_seq_id})->select;
      return 'Yes' if ($ph && $ph->v_trim_start);
    } else {
      my $seq = $s->Seq({-id=>$p->src_seq_id})->select;
      return 'Yes' if $seq && determineVTrim($s,$seq->seq_name);
    }
  }
  return;
}

