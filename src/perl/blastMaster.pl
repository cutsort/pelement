#!/usr/local/bin/perl -I../modules

=head1 NAME

  blastMaster.pl determine what sequences need blasting/aligning

=head1 USAGE

  blastMaster.pl [options]

=cut

use Pelement;
use Session;
use PCommon;
use Getopt::Long;
use strict;

my $session = new Session();

my $report;   # report needed blasting, but do not do them
GetOptions( "report!"      => \$report,
           );


my $to_do = $session->Blast_To_DoSet($session)->select;

foreach my $task ($to_do->as_list) {
  $session->info("Need to run ".$task->seq_name." against db ".$task->database);

  next if $report;

  if ($task->database eq 'all') {

    $session->verbose(shell("./runBlast.pl ".$task->seq_name));
    $session->verbose(shell("./runBlast.pl -protocol te ".$task->seq_name));
    $session->verbose(shell("./runBlast.pl -protocol vector ".$task->seq_name));
    $session->verbose(shell("./alignSeq.pl ".$task->seq_name));

  } elsif ($task->database eq 'na_te.dros') {
    shell("./runBlast.pl -protocol te ".$task->seq_name);
  } elsif ($task->database eq 'vector') {
    shell("./runBlast.pl -protocol vector ".$task->seq_name);
  } elsif ($task->database eq 'release3_genomic') {
    # need to look for deselected/curated alignments
    my $old_aSet = $session->Seq_AlignmentSet({-seq_name=>$task->seq_name})->select;
    $session->verbose("We have ".$old_aSet->count." old alignments.");
    # we're going to delete these from the db; but we still have the objects
    $old_aSet->delete;
    $session->verbose(shell("./runBlast.pl -delete ".$task->seq_name));
    $session->verbose(shell("./alignSeq.pl ".$task->seq_name));
    my $new_aSet = $session->Seq_AlignmentSet({-seq_name=>$task->seq_name})->select;
    # go through every pair and try to reconcile new and old
    foreach my $old ($old_aSet->as_list) {
      foreach my $new ($new_aSet->as_list) {
        # same scaffold?
        next unless $old->scaffold eq $new->scaffold;
        # same orientation?
        next unless (($old->p_start < $old->p_end) == ($new->p_start < $new->p_end));
        # something overlaps?
        next unless overlaps($old->s_start,$old->s_end,$new->s_start,$new->s_end);
        if ($old->status eq 'curated') {
          $session->verbose("An old curated alignment on ".$old->scaffold." at ".
                                                           $old->s_insert." is being transfered.");
          $new->status('curated');
          $new->update;
          # we reset the status on old so that 2 alignments do not get promoted
          $old->status('processed');
        } elsif ($old->status eq 'deselected') {
          $session->verbose("An old deselected alignment on ".$old->scaffold." at ".
                                                           $old->s_insert." is being transfered.");
          $new->status('deselected');
          $new->update;
          $old->status('processed');
        } elsif ($old->status eq 'unwanted') {
          $session->verbose("An old unwanted alignment on ".$old->scaffold." at ".
                                                           $old->s_insert." is being transfered.");
          $new->status('unwanted');
          $new->update;
          $old->status('processed');
        }
      }
    }
    # look for any un-processed curated alignments
    foreach my $old ($old_aSet->as_list) {
      if ($old->status eq 'curated') {
        $session->warn("UNTRANSFERRED CURATED ALIGNMENT of ".$old->seq_name." to ".$old->scaffold." at ".$old->s_insert);
      }
    }
  }
}

$session->exit();

exit(0);


sub overlaps {
  # do we overlap?
  my ($c,$d,$e,$f) = @_;
  ($c,$d) = sort { $a <=> $b } ($c,$d);
  ($e,$f) = sort { $a <=> $b } ($e,$f);
  return ( ( $e >= $c && $e <= $d) || ($f >= $c && $f <= $d) || ($e <= $c && $f >= $d));
}

