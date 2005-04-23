#!/usr/local/bin/perl -I../modules

=head1 NAME

  batchReport.pl Web report of the batch processing information.

=cut

use Pelement;
use Session;
use Batch;
use Digestion;
use Ligation;
use IPCR;
use Gel;
use DigestionSet;
use LigationSet;
use SampleSet;
use Sample;
use Seq;
use SeqSet;
use Seq_Assembly;
use Seq_AlignmentSet;
use Blast_ReportSet;
use GenBankScaffold;
use Strain;
use IPCRSet;
use GelSet;
use Lane;
use LaneSet;
use Cytology;
use Phred_Seq;
use PelementCGI;
use PelementDBI;

use strict;

my $cgi = new PelementCGI;
my $batch = $cgi->param('batch');

print $cgi->header();
print $cgi->init_page({-title=>"Batch $batch Report"});
print $cgi->banner();


if ($batch) {
   my @batch = $cgi->param('batch');
   while (@batch) {
      $batch = shift @batch;
      reportBatch($cgi,$batch);
   }
} else {
   selectBatch($cgi);
}

if ($batch) {
  my $prev_batch = $batch - 1;
  my $next_batch = $batch + 1;
  print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                   {link=>"setReport.pl",name=>"Set Report"},
                   {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                   {link=>"batchReport.pl?batch=$prev_batch",name=>"Previous Batch"},
                   {link=>"batchReport.pl?batch=$next_batch",name=>"Next Batch"}
                    ]);
} else {
  print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                   {link=>"setReport.pl",name=>"Set Report"},
                   {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                    ]);
}
print $cgi->close_page();

exit(0);


sub selectBatch
{

   my $cgi = shift;

   if ($cgi->param('strain')) {

      # we have a strain id. produce links for the batches this
      # is in.

      my $session = new Session({-log_level=>0});
      my $sampleSet = new SampleSet($session,{-strain_name=>$cgi->param('strain')})->select();
      
      my @tableRows = ();
      foreach my $s ($sampleSet->as_list) {
         
         my $ba = new Batch($session,{-id=>$s->batch_id});
         next unless $ba->db_exists;
         $ba->select;
         push @tableRows, [
                   $s->strain_name,uc($s->well),
                   $cgi->a({-href=>"batchReport.pl?batch=".$ba->id},"Batch ".$ba->id),
                   $ba->batch_date || $cgi->nbsp ];
      }

      if (@tableRows) {
                          
         print $cgi->center($cgi->table({-border=>2,
                                   -width=>"80%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'10%'},
                      ["Strain".$cgi->br."Name"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["Well"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'15%'},
                      ["Batch","Date"]),
                      (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";
      } else {
          print $cgi->h3("No batches were found for strain ".$cgi->param('strain')),"\n";
      }
      $session->exit;
            
   } else {

      # nothing is given. present a form to type into.
      print
        $cgi->center(
          $cgi->h3("Enter the Batch Number or Strain Id:"),"\n",
          $cgi->br,
          $cgi->start_form(-method=>"get",-action=>"batchReport.pl"),"\n",
             $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
                $cgi->Tr( [
                 $cgi->td({-align=>"right",-align=>"left"},
                       ["Batch",$cgi->textfield(-name=>"batch")]),
                 $cgi->td({-align=>"right",-align=>"left"},
                       [$cgi->em('or').' Strain',$cgi->textfield(-name=>"strain")]),
                 $cgi->td({-colspan=>2,-align=>"center"},
                            [$cgi->submit(-name=>"Report")]),
                 $cgi->td({-colspan=>2,-align=>"center"},
                            [$cgi->reset(-name=>"Clear")]) ]
                ),"\n",
             ),"\n",
          $cgi->end_form(),"\n",
          ),"\n";
   }
}

sub reportBatch
{
   my ($cgi,$batch) = @_;

   my $session = new Session({-log_level=>0});

   # are we going to show ALL alignments for these strains?
   my $allAlign = ($cgi->param('align') eq 'all')?1:0;

   # try to make sense of the strain name. It may have an end identifier.
   my $bObj = new Batch($session,{-id=>$batch})->select;

   if ( !$bObj->db_exists ) {
      print $cgi->center($cgi->h2("No recorded batch $batch.")),"\n";
      return;
   }

   my @rows = ();
   my @cols = ();
   my %samples = ();
   my %sampleLinks = ();
   my %statusLinks = ();
   my $sampleSet = new SampleSet($session,{-batch_id=>$bObj->id})->select;
   foreach my $s ($sampleSet->as_list) {
      my $well = $s->well;
      my ($r,$c) = ($well =~ /^(.)(\d+)$/);
      $r = uc($r);
      push @rows, $r unless grep (/^$r$/,@rows);
      push @cols, $c unless grep (/^$c$/,@cols);
      $samples{$r.":".$c} = $s->strain_name;
      $sampleLinks{$r.":".$c} = $cgi->a({-href=>"strainReport.pl?strain=".
                                         $s->strain_name},$s->strain_name);
      my $status = new Strain($session,{-strain_name=>$s->strain_name})->select->status;
      $statusLinks{$r.":".$c} = $cgi->a({-href=>"strainStatusReport.pl?strain=".
                                         $s->strain_name},$status);
   }
   @rows = sort { $a cmp $b } @rows;
   @cols = sort { $a <=> $b } @cols;

   print $cgi->center($cgi->h3("Strains in Batch $batch"),$cgi->br),"\n",
         $cgi->center($cgi->format_plate(\@rows,\@cols,\%sampleLinks,
                                              {-align=>'center'})),"\n",
         $cgi->br,
         $cgi->html_only(
            $cgi->a({-href=>"batchReport.pl?batch=$batch&table=plate&format=text"},
                  "View as Tab delimited list"),$cgi->br,"\n"),
         $cgi->br,$cgi->hr,"\n"
                        if (!$cgi->param('table') ||
                             $cgi->param('table') eq 'plate');


   my @tableRows = ();

   my %trHash = ();
  
   $trHash{'0.0'} = ['Batch '.$bObj->id,
                     $bObj->description || $cgi->nbsp ,
                     $bObj->user_login  || $cgi->nbsp,
                     $bObj->batch_date  || $cgi->nbsp];

   my $digCtr = 0;
   my $ligCtr = 0;
   my $ipcrCtr = 0;
   my $gelCtr = 0;
   my @gelList = ();

   my $digSet = new DigestionSet($session,{-batch_id=>$bObj->id})->select;
   foreach my $dig ($digSet->as_list) {
      $trHash{"1.$digCtr"} = ['Digestion '.$dig->name,
                              'Batch '.$dig->batch_id,
                              $dig->user_login || $cgi->nbsp,
                              $dig->digestion_date || $cgi->nbsp];
      $digCtr++;
      my $ligSet = new LigationSet($session,
                                   {-digestion_name=>$dig->name})->select;
      foreach my $lig ($ligSet->as_list) {
         $trHash{"2.$ligCtr"} = ['Ligation '.$lig->name,
                              'Digestion '.$lig->digestion_name,
                              $lig->user_login || $cgi->nbsp,
                              $lig->ligation_date || $cgi->nbsp];
         $ligCtr++;
         my $ipcrSet = new IPCRSet($session,
                                   {-ligation_name=>$lig->name})->select;
         foreach my $ipcr ($ipcrSet->as_list) {
            $trHash{"3.$ipcrCtr"} = ['IPCR '.$ipcr->name,
                              'Ligation '.$ipcr->ligation_name,
                              $ipcr->user_login || $cgi->nbsp,
                              $ipcr->ipcr_date || $cgi->nbsp];
            $ipcrCtr++;
            my $gelSet = new GelSet($session,
                                   {-ipcr_name=>$ipcr->name})->select;
            foreach my $gel ($gelSet->as_list) {
               $trHash{"4.$gelCtr"} = [
                              $cgi->a({-href=>'gelReport.pl?id='.$gel->id},
                                       $gel->name),
                              'IPCR '.$gel->ipcr_name,
                              $gel->user_login || $cgi->nbsp,
                              $gel->gel_date || $cgi->nbsp];
               $gelCtr++;
               push @gelList,$gel;
            }
         }
      }
   }

   map { push @tableRows, $trHash{$_} }
       sort { ( (split(/\./,$a))[0] <=> (split(/\./,$b))[0] ) ||
              ( (split(/\./,$a))[1] <=> (split(/\./,$b))[1] ) } keys %trHash;


   print $cgi->center($cgi->h3("Production records for batch $batch"),
                                   $cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,
                                   -width=>"80%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
         $cgi->Tr( [
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Production".$cgi->br."Step",
                       "Details".$cgi->br."","Person","Date"] ),
                       (map { $cgi->td({-align=>"left"}, $_ ) } @tableRows),
                       ] ))),"\n",
         $cgi->br,
         $cgi->html_only($cgi->a({
             -href=>"batchReport.pl?batch=$batch&table=production&format=text"
                                 },
                  "View as Tab delimited list"),$cgi->br,"\n"),
         $cgi->br,$cgi->hr,"\n"
                        if (!$cgi->param('table') ||
                             $cgi->param('table') eq 'production');

   # the sequence info.

   @tableRows = ();

   # a hash to keep tracks of various stats.
   my %strainSumH = ();
   my %wellSumH = ();
   my %phredSeqH = ('b'=>0,'3'=>0,'5'=>0,'n'=>0);
   my %conSeqH = ('b'=>0,'3'=>0,'5'=>0,'n'=>0);
   my %alignSeqH = ('1'=>0,'c'=>0,'m'=>0,'u'=>0,'5'=>0,'3'=>0);

   foreach my $r (@rows) {
      foreach my $c (@cols) {
         my $s = $samples{$r.':'.$c} || next;
         $strainSumH{$s} = 1;
         $wellSumH{$r.':'.$c} = 1;
         my %endSeq = ();
         my %builtSeq = ();
         my $hitVector;

         my %seqs = ( '5'=>[], '3'=>[], 'other'=>[] );

         # process every gel
         foreach my $gel (@gelList) {
            # and look at every lane in that gel
            foreach my $lane (new LaneSet($session,
                       {-gel_id=>$gel->id,-seq_name=>$s})->select->as_list) {
               # is there a phred'ed sequence"
               my $ph = new Phred_Seq($session,
                       {-lane_id=>$lane->id})->select_if_exists;
               if ($ph->id) {
                  # if q20 is > 25, we got sequence
                  $endSeq{$lane->end_sequenced} = 1 if $ph->q20 > 25;
                  # is this used as part of an assembly?
                  my $sa = new Seq_Assembly($session,
                              {-src_seq_id=>$ph->id,
                               -src_seq_src=>'phred_seq'})->select_if_exists;
                  if ($sa->seq_name) {
                     my $saSeq = new Seq($session,
                             {-seq_name=>$sa->seq_name})->select_if_exists;
                     # have we imported a significant sequence?
                     if ($saSeq->sequence && (1 || length($saSeq->sequence) >= 25)) {
                        # we'll make a comma delimited list of the sequence qualifiers.
                        # "c" is an unqualified (consensus) sequence
                        if (exists($builtSeq{$lane->end_sequenced}) && $saSeq->qualifier) {
                           $builtSeq{$lane->end_sequenced} .= ','.$saSeq->qualifier;
                        } elsif ( $saSeq->qualifier ) {
                          $builtSeq{$lane->end_sequenced} = $saSeq->qualifier;
                        } elsif ( !$saSeq->qualifier ) {
                          $builtSeq{$lane->end_sequenced} = 'c';
                        } elsif (exists($builtSeq{$lane->end_sequenced})
                                      && !grep(/c/,$builtSeq{$lane->end_sequenced})
                                      && !$saSeq->qualifier) {
                          $builtSeq{$lane->end_sequenced} .= ',c';
                        }

                        # does this sequence hit vector? These are not stored
                        # as seq alignments, but we look at blast hits on the fly
                        my $vecReport = new Blast_ReportSet($session,
                                         {-seq_name=>$sa->seq_name,-db=>'vector',
                                          -greater_than=>{score=>50} })->select;

                        $hitVector = 1 if $vecReport->count;
                               
                        my $al = new Seq_AlignmentSet($session,
                                      {-seq_name=>$sa->seq_name})->select;
                        map
                         { push @{$seqs{$lane->end_sequenced}},$_
                                      unless $_->status =~ /deselected/} $al->as_list;
                     }
                  }
               }
            }
         }
         if ($allAlign) {
            # make a hash of the seqs we know about
            my %foundSeq = ();
            map { $foundSeq{$_->seq_name} = 1 } @{$seqs{5}};
            map { $foundSeq{$_->seq_name} = 1 } @{$seqs{3}};
            my $seqSet = new SeqSet($session,{-strain_name=>$s})->select;
            foreach my $nS ($seqSet->as_list) {
               next if $foundSeq{$nS->seq_name};
               my $naS = new Seq_AlignmentSet($session,{-seq_name=>$nS->seq_name})->select;
               map { push @{$seqs{other}},$_
                       unless $_->status =~ /deselected/ || $_->status =~ /multiple/}
                                                $naS->as_list;
            }
         }

         # do we have phred seq for one or more ends?
         my $seqs = (($endSeq{5} && $endSeq{3})?'b':
                    ($endSeq{5}?'5':
                    ($endSeq{3}?'3':'n')));
         $phredSeqH{$seqs}++;

         # do we have consensus seq for one or more ends?
         my $cons = (($builtSeq{5} && $builtSeq{3})?'b':
                    ($builtSeq{5}?'5':
                    ($builtSeq{3}?'3':'n')));
         $conSeqH{$cons}++;
         # qualify this
         foreach my $e qw(5 3) {
            $builtSeq{$e} = join(',', sort { $a cmp $b} split(/,/,$builtSeq{$e}) );
            $cons .= "($e:$builtSeq{$e})" if ($builtSeq{$e} && $builtSeq{$e} ne 'c');
         }


         # do we have alignments? 
         # Symbols for alignment type:
         # 1 -> flank(s) align to a single unique site
         # c -> 5' and 3' flanks align to different unique sites                
         # m -> flank(s) align to multiple sites
         # u -> flank(s) don't align to any site (either no BLAST hits or
         # alignment of flank as a whole below threshold)
         # 5 -> 5' flank aligns to a unique site, 3' flank doesn't align to any
         # site or aligns to multiple sites
         # 3 -> 3' flank aligns to a unique site, 5' flank doesn't align to any
         # site or aligns to multiple sites


         my $align;
         if (scalar(@{$seqs{5}}) == 1 && scalar(@{$seqs{3}}) == 1 ) {
            # both ends, 1 unique spot.
            my $s5 = $seqs{5}->[0];
            my $s3 = $seqs{3}->[0];
            if ($s3->scaffold eq $s5->scaffold &&
                      abs($s3->s_insert - $s5->s_insert) < 100 ) {
               $align = '1';
            } else {
               $align = 'c';
            }
         } elsif (scalar(@{$seqs{5}}) == 1 ) {
            $align = '5';
         } elsif (scalar(@{$seqs{3}}) == 1 ) {
            $align = '3';
         } elsif (scalar(@{$seqs{5}}) == 0 && scalar(@{$seqs{3}}) == 0 ) {
            $align = 'u';
         } else {
            $align = 'm';
         }
         $alignSeqH{$align}++;


         my $place = $cgi->nbsp;
         my $cyto = $cgi->nbsp;
         my $coord = $cgi->nbsp;
         my $strand = $cgi->nbsp;
         my $arm = $cgi->nbsp;
         if ($align =~ /^1/) {
            # happiness abounds. A single unique insert
            my $mean = int(($seqs{5}->[0]->s_insert+$seqs{3}->[0]->s_insert)/2);
            my $scaff = new GenBankScaffold($session)->mapped_from_arm(
                                               $seqs{5}->[0]->scaffold,$mean);
            if ($scaff && $scaff->accession) {
               $place = $cgi->a({-href=>"retrieveXML.pl?name=".$scaff->accession},
                                           $scaff->accession);
            } else {
               $place = $cgi->em('No Acc');
            }
            $cyto = $scaff->cytology;
            $arm = $scaff->arm;
            # see if we can be more specific about the cytology
            my $cyt = new Cytology($session,{-scaffold=>$seqs{5}->[0]->scaffold,
                                            -less_than=>{start=>$mean},
                                -greater_than_or_equal=>{stop=>$mean}})->select_if_exists;
            $cyto = $cyt->band if $cyt->band;
            $coord = $mean;
            $strand = ($seqs{5}->[0]->p_end > $seqs{5}->[0]->p_start)?'+':'-';
         } elsif ($align =~ /^[35]/ ) {
            # semi-happy. 1 good spot
            my $scaff = new GenBankScaffold($session)->mapped_from_arm(
                                              $seqs{$align}->[0]->scaffold,
                                              $seqs{$align}->[0]->s_insert);
            if ($scaff && $scaff->accession) {
               $place = $cgi->a({-href=>"retrieveXML.pl?name=".$scaff->accession},
                                           $scaff->accession);
            } else {
               $place = $cgi->em('No Acc');
            }
            $cyto = $scaff->cytology;
            $arm = $scaff->arm;
            my $cyt = new Cytology($session,{-scaffold=>$seqs{$align}->[0]->scaffold,
                            -less_than=>{start=>$seqs{$align}->[0]->s_insert},
                            -greater_than_or_equal=>{stop=>$seqs{$align}->[0]->s_insert}}
                                                                       )->select_if_exists;
            $cyto = $cyt->band if $cyt->band;
            $coord = $seqs{$align}->[0]->s_insert;
            $strand = ($seqs{$align}->[0]->p_end > $seqs{$align}->[0]->p_start)?'+':'-';
         } elsif ($align =~ /^c/ ) {
            # ooooh. scary. conflicting data
            # first, clear out the space data
            map { $_ = '' } ($place,$coord,$cyto,$arm,$strand);
            foreach my $e qw(3 5) {
               my $scaff = new GenBankScaffold($session)->mapped_from_arm(
                                                 $seqs{$e}->[0]->scaffold,
                                                 $seqs{$e}->[0]->s_insert);

               map { $_ .= $cgi->br if $e eq '5' } ($place,$coord,$cyto,$arm,$strand);

               if ($scaff && $scaff->accession) {
                  $place .= $cgi->a({-href=>"retrieveXML.pl?name=".$scaff->accession},
                                              $scaff->accession);
               } else {
                  $place .= $cgi->em('No Acc');
               }
               $arm .= $scaff->arm;
               my $cyt = new Cytology($session,{-scaffold=>$seqs{$e}->[0]->scaffold,
                               -less_than=>{start=>$seqs{$e}->[0]->s_insert},
                               -greater_than_or_equal=>{stop=>$seqs{$e}->[0]->s_insert}}
                                                                      )->select_if_exists;
               $cyto .= $cyt->band?$cyt->band:($scaff->cytology?$scaff->cytology:'?');
               $coord .= $seqs{$e}->[0]->s_insert;
               $strand .= ($seqs{$e}->[0]->p_end > $seqs{$e}->[0]->p_start)?'+':'-';
            }
            # this should not be needed, but put spaces back in
            map { $_ = $cgi->nbsp unless $_ } ($place,$coord,$cyto,$arm,$strand);
         }

         $arm =~ s/arm_//g;

         my ($otherPlace,$otherArm,$otherCoord,$otherCyto,$otherStrand);
         if ($allAlign) {
            foreach my $osA (@{$seqs{other}}) {
               map { $_ .= $cgi->br if $_}
                         ($otherPlace,$otherArm,$otherCoord,$otherCyto,$otherStrand);
 
               my $scaff = new GenBankScaffold($session)->mapped_from_arm(
                                                 $osA->scaffold,
                                                 $osA->s_insert);
               if ($scaff && $scaff->accession) {
                  $otherPlace .= $cgi->a({-href=>"retrieveXML.pl?name=".$scaff->accession},
                                              $scaff->accession);
               } else {
                  $otherPlace .= $cgi->em('No Acc');
               }
               my $a = $scaff->arm;
               $a =~ s/arm_//;
               $otherArm .= $a;
               my $cyt = new Cytology($session,{-scaffold=>$osA->scaffold,
                               -less_than=>{start=>$osA->s_insert},
                               -greater_than_or_equal=>{stop=>$osA->s_insert}}
                                    )->select_if_exists;
               if ($cyt->band) {
                  $otherCyto .= $cyt->band;
               } else {
                  $otherCyto .= $scaff->cytology;
               }
               $otherCoord .= $osA->s_insert;
               $otherStrand .= ($osA->p_end > $osA->p_start)?'+':'-';
            }
            map { $_ = $cgi->nbsp unless $_ } 
                     ($otherPlace,$otherArm,$otherCoord,$otherCyto,$otherStrand);
         }
            
         $align .= '(v)' if $hitVector;
        
         if ($allAlign) {
            push @tableRows,
              [$batch,$sampleLinks{$r.':'.$c},$r.$c,$seqs,$cons,$align,$place,$arm,
                         $coord,$cyto,$strand,$otherPlace,$otherArm,$otherCoord,
                         $otherCyto,$otherStrand,$statusLinks{$r.':'.$c}];
         } else {
            push @tableRows,
              [$batch,$sampleLinks{$r.':'.$c},$r.$c,$seqs,$cons,$align,$place,$arm,
                         $coord,$cyto,$strand,$statusLinks{$r.':'.$c}];
         }
      }
   }
   print $cgi->center($cgi->h3("Sequence status for strains in batch $batch"),
                       $cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,
                                   -width=>"80%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
      ## header
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'10%'},
                      ["Batch"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'15%'},
                      ["Strain".$cgi->br."Name"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'8%'},
                      ["Well"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'12%'},
                      ["Phred".$cgi->br."Seq",
                       "Consensus".$cgi->br."Seq","Alignment",
                      "Scaffold","Arm","Location","Cytology"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["Strand"]).
               ($allAlign?
                      ($cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'12%'},
                      ["Other".$cgi->br."Scaffolds","Other".$cgi->br."Arms",
                       "Other".$cgi->br."Locations","Other".$cgi->br."Cytologys"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["Other".$cgi->br."Strands"])):'').
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["Status"]),
      ## contents
                        (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
      ## totals
               $cgi->th('Totals').
               $cgi->th(scalar(keys %strainSumH)).
               $cgi->th(scalar(keys %wellSumH)).
               $cgi->th('b: '.$phredSeqH{b}.$cgi->br.
                        '5: '.$phredSeqH{5}.$cgi->br.
                        '3: '.$phredSeqH{3}.$cgi->br.
                        'n: '.$phredSeqH{n}.$cgi->br).
               $cgi->th('b: '.$conSeqH{b}.$cgi->br.
                        '5: '.$conSeqH{5}.$cgi->br.
                        '3: '.$conSeqH{3}.$cgi->br.
                        'n: '.$conSeqH{n}.$cgi->br).
               $cgi->th('1: '.$alignSeqH{1}.$cgi->br.
                        '5: '.$alignSeqH{5}.$cgi->br.
                        '3: '.$alignSeqH{3}.$cgi->br.
                        'm: '.$alignSeqH{m}.$cgi->br.
                        'c: '.$alignSeqH{c}.$cgi->br.
                        'u: '.$alignSeqH{u}.$cgi->br).
               $cgi->th($cgi->nbsp).
               $cgi->th($cgi->nbsp).
               $cgi->th($cgi->nbsp).
               $cgi->th($cgi->nbsp).
               $cgi->th($cgi->nbsp).
               ($allAlign?($cgi->th($cgi->nbsp).$cgi->th($cgi->nbsp).
                           $cgi->th($cgi->nbsp).$cgi->th($cgi->nbsp).
                           $cgi->th($cgi->nbsp).$cgi->th($cgi->nbsp)):'').
               $cgi->th($cgi->nbsp),
                       ] ))),"\n",
         $cgi->br,
         $cgi->html_only($cgi->a(
                  {-href=>"batchReport.pl?batch=$batch&table=align&align=all"},
                  "View Alignments of these strains from all batches"),$cgi->br,"\n"),
         $cgi->html_only($cgi->a(
                  {-href=>"batchReport.pl?batch=$batch&table=align&format=text"},
                  "View Alignments from this batch as Tab delimited list"),$cgi->br,"\n"),
         $cgi->html_only($cgi->a(
                   {-href=>"batchReport.pl?batch=$batch&table=align&align=all&format=text"},
                  "View Alignments of these strains from all batches as Tab delimited list"),
                  $cgi->br,"\n"),$cgi->br,"\n"
                        if (!$cgi->param('table') ||
                             $cgi->param('table') eq 'align');

   print $cgi->em('Sequence Key:',
         $cgi->ul($cgi->li([qq(b -> sequence for both ends,).
                            $cgi->br.
                            qq(more that 25 bp q20 or better for phred,
                               or more than 25 bp of consensus),
                            qq(5 -> sequence for 5' end only),
                            qq(3 -> sequence for 3' end only),
                            qq(n -> sequence for neither end),
                            qq(a parenthetical note on sequences indicates one
                               or both ends is not the current consensus),
                                                    ]))), "\n",
         $cgi->em('Alignment Key:',
         $cgi->ul($cgi->li([ 
             qq(1 -> flank(s) align to a single unique site),
             qq(c -> 5' and 3' flanks align to different unique sites),
             qq(m -> flank(s) align to multiple sites),
             qq(u -> flank(s) don't align to any site
                     (either no BLAST hits or alignment of flank as
                     a whole below threshold)),
             qq(5 -> 5' flank aligns to a unique site, 3' flank
                     doesn't align to any site or aligns to multiple sites),
             qq(3 -> 3' flank aligns to a unique site, 5' flank
                     doesn't align to any site or aligns to multiple sites),
             qq(v -> one or both flanks show significant alignment to vector)]))),
          "\n"
                        if (!$cgi->param('table') );
            
  $session->exit();
}
