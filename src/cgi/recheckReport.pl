#!/usr/bin/env perl
use FindBin::libs 'base=modules';

=head1 NAME

  recheckReport.pl Web report of the batch recheck information

=cut

use Pelement;
use PelementCGI;
use PelementCGI;;
use PelementDBI;
use Batch;
use DigestionSet;
use GelSet;
use IPCRSet;
use LaneSet;
use LigationSet;
use Phred_Seq;
use Seq;
use SampleSet;
use Seq_Assembly;
use Seq_AssemblySet;
use Session;

# George's sim4-er
use GH::Sim4;

use strict;

my $cgi = new PelementCGI;
my $batch = $cgi->param('batch');

print $cgi->header();
print $cgi->init_page({-title=>"$batch Recheck Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
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
                   {link=>"recheckReport.pl",name=>"Recheck Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                   {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                   {link=>"recheckReport.pl?batch=$prev_batch",name=>"Previous Batch Recheck"},
                   {link=>"recheckReport.pl?batch=$next_batch",name=>"Next Batch Recheck"}
                    ]);
} else {
  print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"recheckReport.pl",name=>"Recheck Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
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
                   $cgi->a({-href=>"recheckReport.pl?batch=".$ba->id},"Batch ".$ba->id),
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
          $cgi->start_form(-method=>"get",-action=>"recheckReport.pl"),"\n",
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

   # try to make sense of the strain name.
   my $bObj = new Batch($session,{-id=>$batch})->select;

   if ( !$bObj->db_exists ) {
      print $cgi->center($cgi->h2("No record of batch $batch.")),"\n";
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



   # march the batch ID's forward to find all associated lanes.

   my @gelList = ();

   my $digSet = new DigestionSet($session,{-batch_id=>$bObj->id})->select;
   foreach my $dig ($digSet->as_list) {
      my $ligSet = new LigationSet($session,
                                   {-digestion_name=>$dig->name})->select;
      foreach my $lig ($ligSet->as_list) {
         my $ipcrSet = new IPCRSet($session,
                                   {-ligation_name=>$lig->name})->select;
         foreach my $ipcr ($ipcrSet->as_list) {
            my $gelSet = new GelSet($session,
                                   {-ipcr_name=>$ipcr->name})->select;
            foreach my $gel ($gelSet->as_list) {
               push @gelList,$gel;
            }
         }
      }
   }

   my @tableRows = ();

   foreach my $r (@rows) {
      foreach my $c (@cols) {
         my $s = $samples{$r.':'.$c} || next;

         my %seqs = ( '5'=>[], '3'=>[] );

         my @minitableRows = ();
         my $matches = 0;
         foreach my $gel (@gelList) {
            foreach my $lane (new LaneSet($session,
                       {-gel_id=>$gel->id,-seq_name=>$s})->select->as_list) {

               my $status = 'Lane data not processed.';
               my $ph = new Phred_Seq($session,
                       {-lane_id=>$lane->id})->select_if_exists;
               if ($ph->id) {
                  $status = 'No assembled sequence';
                  my $sa = new Seq_Assembly($session,
                              {-src_seq_id=>$ph->id,
                               -src_seq_src=>'phred_seq'})->select_if_exists;
                  if ($sa->seq_name) {
                     my $sid = (new Seq($session,{-seq_name=>$sa->seq_name}))->select->id;
                     # and see how many base sequences make up this assembly
                     my $sa2 = new Seq_AssemblySet($session,
                                                  {-src_seq_src=>'phred_seq',
                                                   -seq_name=>$sa->seq_name})->select;
                     my $homany = scalar($sa2->as_list);
                     if ($homany > 2) {
                       $status = 'Assembled with '.($homany-1).' other seqs in consensus sequence '.
                           $cgi->a({-href=>"seqReport.pl?db=seq&id=$sid",-target=>"baseseq"},$sa->seq_name);
                     } elsif ($homany == 2) {
                       $status = 'Assembled with 1 other seq in consensus sequence '.
                           $cgi->a({-href=>"seqReport.pl?db=seq&id=$sid",-target=>"baseseq"},$sa->seq_name);
                     } else {
                       $status = 'Stored in database sequence '.
                           $cgi->a({-href=>"seqReport.pl?db=seq&id=$sid",-target=>"baseseq"},$sa->seq_name);
                     }
                  } else {
                     $status = compareToSave($session,$cgi,$ph->id,$lane->seq_name,$lane->end_sequenced);
                  }
               }
               push @minitableRows,
                   [$cgi->a({-href=>'gelReport.pl?id='.$gel->id},$gel->name),
                           $lane->end_sequenced,$status];
               # a 'confirmed' match is one where this sequence matches or is assembled with another.
               $matches = 1 if ($status =~ /matches/i);
               $matches = 1 if ($status =~ /assembled/i);
               # an 'bad' match is onw where we have no supporting evidence and this does not match.
               $matches = -1 if ($status =~ /does not match/ && $matches == 0);
            }
         }


         my $status = $cgi->table({-border=>2,
                                   -width=>"100%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
                        (map { $cgi->td({-align=>"center"}, $_ ) } @minitableRows),
                       ] ))."\n";


         if ($matches == 0 ) {
            $matches = $cgi->font({-color=>'orange'},'Unknown');#'<font color="yellow">Unknown</font>';
         } elsif ($matches == 1) {
            $matches = $cgi->font({-color=>'green'},'Good');#'<font color="green">Good</font>';
         } elsif ($matches == -1) {
            $matches = $cgi->font({-color=>'red'},'Bad');#'<font color="red">Bad</font>';
         }

         push @tableRows,
              [$sampleLinks{$r.':'.$c},$r.$c,$status,$matches];
      }
   }
   print $cgi->center($cgi->h3("Recheck status for strains in batch $batch"),
                       $cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,
                                   -width=>"80%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
## header
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'15%'},
                      ["Strain".$cgi->br."Name"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["Well"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'70%'},
                      ["Status"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'10%'},
                      ["Match"]),
## contents
                        (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
## totals
                       ] ))),"\n",
         $cgi->br,
         $cgi->html_only($cgi->a({-href=>"recheckReport.pl?batch=$batch&format=text"},
                  "View as Tab delimited list"),$cgi->br,"\n"),
          $cgi->br,"\n";

  $session->exit();
}

sub compareToSave
{
   my $session = shift;
   my $cgi = shift;
   my $phred_id = shift;

   my $seq_name = shift;
   my $end = shift;

   return 'phred id not specified' unless $phred_id;
   return 'sequence name not specified' unless $seq_name;
   return 'end not specified' unless $end;

   my $newSeq = new Phred_Seq($session,{-id=>$phred_id});
   return 'Cannot locate phred sequence $phred_id' unless $newSeq->db_exists;
   $newSeq->select;

   my $trimStatus;

   $newSeq->seq($newSeq->trimmed_seq);

   return $cgi->a({-href=>"seqReport.pl?db=phred_seq&id=$phred_id",-target=>"newseq"},"Sequence").
                " (".length($newSeq->seq)." bp) is too short for comparison." if length($newSeq->seq) < 14;


   $seq_name .= '-'.$end;
   my $baseSeq = new Seq($session,{-seq_name=>$seq_name});
   return 'No stored sequence for this flank.' unless $baseSeq->db_exists;
   $baseSeq->select;

   my $strand = ($end eq '5')?1:0;

   my $s = GH::Sim4::sim4(uc($newSeq->seq),uc($baseSeq->sequence),{R=>$strand});

   my $retStr;
   if ( $s->{exon_count} ) {
      if ($s->{exon_count} == 1 ) {
         my %h = %{$s->{exons}[0]};
         $retStr = $cgi->a({-href=>"seqReport.pl?db=phred_seq&id=$phred_id",-target=>"newseq"},"Sequence").
                   " $h{from1}-$h{to1} matches $h{from2}-$h{to2} of ".
                   $cgi->a({-href=>"seqReport.pl?db=seq&id=".$baseSeq->id,-target=>"baseseq"},$seq_name).
                   " $h{nmatches}/$h{length}";
      } else {
         $retStr = $cgi->a({-href=>"seqReport.pl?db=phred_seq&id=$phred_id",-target=>"newseq"},"Sequence").
                   " matches ".
                   $cgi->a({-href=>"seqReport.pl?db=seq&id=".$baseSeq->id,-target=>"baseseq"},$seq_name).
                   " in ".$s->{exon_count}." exons:";
         foreach my $h (@{$s->{exons}}) {
            my %h = %$h;
            $retStr .=  "$h{from1}-$h{to1} matches $h{from2}-$h{to2} for $h{nmatches}/$h{length},";
         }
         $retStr =~ s/,$//;
      }
   } else {
      $retStr = $cgi->a({-href=>"seqReport.pl?db=phred_seq&id=$phred_id",-target=>"newseq"},"Sequence").
                " (".length($newSeq->seq)." bp) does not match ".
                $cgi->a({-href=>"seqReport.pl?db=seq&id=".$baseSeq->id,-target=>"baseseq"},$seq_name);
   }
   return $retStr;

}
