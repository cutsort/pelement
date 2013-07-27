#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

use Pelement;
use Session;
use GeneModelSet;
use strict;

my $session = new Session;

my $rel = 3;

foreach my $arm (qw(X 2L 2R 3L 3R 4)) {
  my $chado;
  if (my $grab_from_real_chado = 0 ) {
    my $chado_session = new Session({-log_level=>0,
                  -dbistr=>'dbi:Pg:dbname=chacrm_4_2;host=mastermind.lbl.gov'});
    $chado = new ChadoGeneModelSet($chado_session,
                   $arm)->select;
    $chado_session->exit;
  } else {
    $chado = $session->GeneModelSet($arm.'.rel'.$rel)->select;
  }

  # repackage these to group the exons into transcripts.
  my %models;
  foreach my $exon ($chado->as_list) {
    # why is chado messed up?
    $exon->transcript_name($exon->transcript_uniquename)
                                     if $exon->transcript_name =~ /^-/;
    unless ( exists($models{$exon->transcript_name}) ) {
      $models{$exon->transcript_name} = {start=>$exon->exon_start,
                                           end=>$exon->exon_end,
                                        strand=>$exon->exon_strand,
                                   start_codon=>'',
                                    stop_codon=>'',
                     exons=>[[$exon->exon_start,$exon->exon_end,$exon->exon_uniquename]] };
    } else {
      $models{$exon->transcript_name}->{start} = $exon->exon_start
               if $exon->exon_start < $models{$exon->transcript_name}->{start};
      $models{$exon->transcript_name}->{end} = $exon->exon_end
               if $exon->exon_end > $models{$exon->transcript_name}->{end};
      push @{$models{$exon->transcript_name}->{exons}},
                              [$exon->exon_start,$exon->exon_end,$exon->exon_uniquename];
      # and the start and stop codons?
      # this is anathema to the whole chado spirit
      foreach my $end (qw(start stop)) {
        my $f = $session->flybase::Feature({-name=>$exon->transcript_name.'_'.$end})->select_if_exists;
        if ($f && $f->feature_id) {
          my $fs = $session->flybase::FeatureLoc({-feature_id=>$f->feature_id})->select_if_exists;
          $models{$exon->transcript_name}->{$end.'_codon'} = $fs->fmin if $fs && $fs->fmin ne '';
        }
      }
  
    }
  }
      

  foreach my $g ( sort { $models{$a}->{start} <=> $models{$b}->{start} } keys %models ) {

    my $this_strand = $models{$g}->{strand}>0?1:-1;
    foreach my $e ( sort { $a->[0]*$this_strand <=> $b->[0]*$this_strand }
                                                   @{$models{$g}->{exons}} ) {
      # as far as I can tell, building the models means splitting
      # the exons into coding and non-coding explictly.

      my $line = join("\t",($g,$arm,$models{$g}->{start},$models{$g}->{end},$models{$g}->{strand},
                            $e->[0],$e->[1],$e->[2]));

      my $this_start;
      my $this_stop;
      my $cds_stat;
      if ($this_strand>0) {
        $this_start = $models{$g}->{start_codon} + $models{$g}->{start};
        $this_stop = $models{$g}->{stop_codon} + $models{$g}->{start};
      } else {
        $this_start = $models{$g}->{end} - $models{$g}->{start_codon};
        $this_stop = $models{$g}->{end} - $models{$g}->{stop_codon};
      }
      if ( ($this_strand > 0 && ($e->[1] < $this_start) ) ||
           ($this_strand < 0 && ($e->[0] > $this_start) ) ) {
        $cds_stat = "5' UTR";
      } elsif ( ($this_strand > 0 && ($e->[0] > $this_stop) ) ||
                ($this_strand < 0 && ($e->[1] < $this_stop) ) ) {
        $cds_stat = "3' UTR";
      } else {
        if ( ($this_strand > 0 && ($e->[0] <= $this_start) ) ||
             ($this_strand < 0 && ($e->[1] >= $this_start) ) ) {
          $cds_stat = "Start at $this_start ";
        }
       if ( ($this_strand > 0 && ($e->[1] >= $this_stop) ) ||
            ($this_strand < 0 && ($e->[0] <= $this_stop) ) ) {
          $cds_stat .= ' ' if $cds_stat;
          $cds_stat .= "Stop at $this_stop";
        }
      }
      $cds_stat = 'Coding' unless $cds_stat;
      print $line,"\t",$cds_stat,"\n";
    }


  }

  $session->exit;

}

