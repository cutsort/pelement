#!/usr/bin/env perl
use FindBin::libs 'base=modules';

=head1 NAME

  analyzeStrain.pl look at decide on status

=head1 USAGE

  analyzerStrain.pl [options] strain_name

=head1 Options

=item  -min N


=item  -max N


=cut

use Pelement;
use PCommon;
use Session;
use Files;
use GeneModelSet;

use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();



GetOptions();

print join("\t",("Strain","Status",
                 "5' Arm","5' Seq Rel 4 Coord","5' Seq Rel 3 Coord","5' Seq Strand","5' Gene Hit",
                 "3' Arm","3' Seq Rel 4 Coord","3' Seq Rel 3 Coord","3' Seq Strand","3' Gene Hit")),"\n";
while (my $strain_name = shift @ARGV ) {
  my $strain = $session->Strain({-strain_name=>$strain_name});
  $session->die("$strain_name is not a known strain.") unless $strain->db_exists;
  $strain->select;
  my $seqS = $session->SeqSet({-strain_name=>$strain->strain_name})->select;

  unless ($seqS->count) {
    print join("\t",($strain_name,"No Sequence")),"\n";
    next;
  }

  my @blank = ('','','','','');
  my %endInfo;
  foreach my $seq ($seqS->as_list) {
    my $align = $session->Seq_AlignmentSet({-seq_name    => $seq->seq_name,
                                            -seq_release => '3' })->select;
  
    foreach my $a ($align->as_list) {
      next unless $a->status eq 'unique' || $a->status eq 'curated';
      next unless $a->seq_name =~ /-[35]$/;
      my $scaffold = $a->scaffold;
      $scaffold =~ s/^arm_//;
      my $insert = $a->s_insert;
      my $r4 = $session->db->select_value("select r3_r4_map('$scaffold',$insert)");
      if ($a->seq_name =~ /-3$/) {
       $endInfo{3} = [$scaffold,$r4,$insert,
                      (($a->p_start>$a->p_end)==($a->s_start>$a->s_end)?+1:-1)];
      } elsif ($a->seq_name =~ /-5$/) {
       $endInfo{5} = [$scaffold,$r4,$insert,
                      (($a->p_start>$a->p_end)==($a->s_start>$a->s_end)?+1:-1)];
      } else {
        $session->die("What is this sequence name? ".$a->seq_name);
      }
    }
  }

  foreach my $end (qw( 3 5 )) {
    next unless $endInfo{$end};
    next unless my $arm = $endInfo{$end}->[0];
    next unless my $r4 = $endInfo{$end}->[1];
    my $genes = new GeneModelSet($session,$arm.'.rel4',$r4-5000,$r4+5000)->select;
    my $hits = "No gene";
    foreach my $exon ($genes->as_list) {
      $hits = "In exon ".$exon->gene_name if ($r4>=$exon->exon_start && $r4<=$exon->exon_end);
      if ($hits !~ /exon/ ) {
        $hits = "In intron ".$exon->gene_name if ($r4>=$exon->transcript_start && $r4<=$exon->transcript_end);
        if ($hits !~ /intron/ ) {
          $hits = "Near gene ".$exon->gene_name
              if (($r4>=$exon->gene_start-500 &&
                   $r4<=$exon->transcript_start &&
                   $exon->gene_strand == 1) ||
                  ($r4<=$exon->gene_end+500 &&
                   $r4>=$exon->transcript_end &&
                   $exon->gene_strand == -1)); 
        }
      }
    }
    push @{$endInfo{$end}},$hits;
  }
  print join("\t",($strain_name,$strain->status,$endInfo{5}?@{$endInfo{5}}:@blank,$endInfo{3}?@{$endInfo{3}}:@blank)),"\n";
}

$session->exit();

exit(0);

