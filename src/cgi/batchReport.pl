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
use Seq_Assembly;
use Seq_AlignmentSet;
use GenBankScaffold;
use IPCRSet;
use GelSet;
use Lane;
use Cytology;
use Phred_Seq;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;
my $batch = $cgi->param('batch');

print $cgi->header();
print $cgi->init_page();
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

print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                    ]);
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
   my $sampleSet = new SampleSet($session,{-batch_id=>$bObj->id})->select;
   foreach my $s ($sampleSet->as_list) {
      my $well = $s->well;
      my ($r,$c) = ($well =~ /^(.)(\d+)$/);
      $r = uc($r);
      push @rows, $r unless grep (/^$r$/,@rows);
      push @cols, $c unless grep (/^$c$/,@cols);
      $samples{$r.":".$c} = $s->strain_name;
      $sampleLinks{$r.":".$c} = $cgi->a({-href=>"strainReport.pl?strain=".$s->strain_name},$s->strain_name);
   }
   @rows = sort { $a cmp $b } @rows;
   @cols = sort { $a <=> $b } @cols;

   print $cgi->center($cgi->h3("Strains in Batch $batch"),$cgi->br),"\n",
         $cgi->center($cgi->format_plate(\@rows,\@cols,\%sampleLinks,
                                              {-align=>'center'})),"\n",
         $cgi->br,
         $cgi->html_only($cgi->a({-href=>"batchReport.pl?batch=$batch&table=plate&format=text"},
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
         $cgi->html_only($cgi->a({-href=>"batchReport.pl?batch=$batch&table=production&format=text"},
                  "View as Tab delimited list"),$cgi->br,"\n"),
         $cgi->br,$cgi->hr,"\n"
                        if (!$cgi->param('table') ||
                             $cgi->param('table') eq 'production');

   # the sequence info.

   @tableRows = ();
   foreach my $r (@rows) {
      foreach my $c (@cols) {
         my $s = $samples{$r.':'.$c} || next;
         my %endSeq = ();
         my %builtSeq = ();

         my %seqs = ( '5'=>[], '3'=>[] );

         foreach my $gel (@gelList) {
            my $lane = new Lane($session,
                       {-gel_id=>$gel->id,-seq_name=>$s})->select_if_exists;
            if ($lane && $lane->id) {
               my $ph = new Phred_Seq($session,
                       {-lane_id=>$lane->id})->select_if_exists;
               if ($ph->id) {
                  $endSeq{$lane->end_sequenced} = 1 if $ph->q20 > 25;
                  my $sa = new Seq_Assembly($session,
                              {-phred_seq_id=>$ph->id})->select_if_exists;
                  if ($sa->seq_name) {
                     my $saSeq = new Seq($session,
                             {-seq_name=>$sa->seq_name})->select_if_exists;
                     if ($saSeq->sequence && length($saSeq->sequence) >= 25) {
                        $builtSeq{$lane->end_sequenced} = 1;
                        my $al = new Seq_AlignmentSet($session,
                                      {-seq_name=>$sa->seq_name})->select;
                        push @{$seqs{$lane->end_sequenced}},$al->as_list;
                     }
                  }
               }
            }
         }
        
         # do we have phred seq for one or more ends?
         my $seqs = (($endSeq{5} && $endSeq{3})?'b':
                    ($endSeq{5}?'5':
                    ($endSeq{3}?'3':'n')));

         # do we have consensus seq for one or more ends?
         my $cons = (($builtSeq{5} && $builtSeq{3})?'b':
                    ($builtSeq{5}?'5':
                    ($builtSeq{3}?'3':'n')));
                    


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
                      abs($s3->s_insert - $s5->s_insert) < 10 ) {
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

         my $place = $cgi->nbsp;
         my $cyto = $cgi->nbsp;
         my $coord = $cgi->nbsp;
         my $strand = $cgi->nbsp;
         my $arm = $cgi->nbsp;
         if ($align eq '1') {
            my $mean = int(($seqs{5}->[0]->s_insert+$seqs{3}->[0]->s_insert)/2);
            my $scaff = new GenBankScaffold($session)->mapped_from_arm(
                                               $seqs{5}->[0]->scaffold,$mean);
            $place = $cgi->a({-href=>"retrieveXML.pl?name=".$scaff->accession},
                                           $scaff->accession);
            $cyto = $scaff->cytology;
            $arm = $scaff->arm;
            # see if we can be more specific about the cytology
            my $cyt = new Cytology($session,{-scaffold=>$seqs{5}->[0]->scaffold,
                                              -less_than_or_equal=>{start=>$mean},
                                              -greater_than_or_equal=>{stop=>$mean}})->select_if_exists;
            $cyto = $cyt->band if $cyt->band;
            $coord = $mean;
            $strand = ($seqs{5}->[0]->p_end > $seqs{5}->[0]->p_start)?'+':'-';
         } elsif ($align eq '3' || $align eq '5') {
            my $scaff = new GenBankScaffold($session)->mapped_from_arm(
                                              $seqs{$align}->[0]->scaffold,
                                              $seqs{$align}->[0]->s_insert);
            $place = $cgi->a({-href=>"retrieveXML.pl?name=".$scaff->accession},
                                           $scaff->accession);
            $cyto = $scaff->cytology;
            $arm = $scaff->arm;
            my $cyt = new Cytology($session,{-scaffold=>$seqs{$align}->[0]->scaffold,
                                              -less_than_or_equal=>{start=>$seqs{$align}->[0]->s_insert},
                                              -greater_than_or_equal=>{stop=>$seqs{$align}->[0]->s_insert}})->select_if_exists;
            $cyto = $cyt->band if $cyt->band;
            $coord = $seqs{$align}->[0]->s_insert;
            $strand = ($seqs{$align}->[0]->p_end > $seqs{$align}->[0]->p_start)?'+':'-';
         }
            
         $arm =~ s/^arm_//;
         push @tableRows,
              [$batch,$sampleLinks{$r.':'.$c},$r.$c,$seqs,$cons,$align,$place,$arm,$coord,$cyto,$strand];
      }
   }
   print $cgi->center($cgi->h3("Sequence status for strains in batch $batch"),
                       $cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,
                                   -width=>"80%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'10%'},
                      ["Batch"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'15%'},
                      ["Strain".$cgi->br."Name"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'8%'},
                      ["Well"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'12%'},
                      ["Phred".$cgi->br."Seq",
                       "Consensus".$cgi->br."Seq",
                       "Alignment","Scaffold","Arm","Location","Cytology"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["Strand"]),
                        (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] ))),"\n",
         $cgi->br,
         $cgi->html_only($cgi->a({-href=>"batchReport.pl?batch=$batch&table=align&format=text"},
                  "View as Tab delimited list"),$cgi->br,"\n"),
          $cgi->br,"\n"
                        if (!$cgi->param('table') ||
                             $cgi->param('table') eq 'align');

   print $cgi->em('Sequence Key:',
         $cgi->ul($cgi->li([qq(b -> sequence for both ends),
                            qq(5 -> sequence for 5' end only),
                            qq(3 -> sequence for 3' end only),
                            qq(n -> sequence for neither end),
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
                     doesn't align to any site or aligns to multiple sites)]))),
          "\n"
                        if (!$cgi->param('table') );
            
  $session->exit();
}
