#!/usr/local/bin/perl -I../modules

=head1 NAME

  updateInsertionPos.pl update the insertion position.

=head1 USAGE

  updateInsertionPos.pl [options] <seq_name>

=cut

use Pelement;
use PCommon;
use PelementDBI;
use Seq;
use Seq_Alignment;
use Seq_AlignmentSet;
use Session;
use Blast_Report;
use Blast_ReportSet;
use Files;
use strict;

use Getopt::Long;

my $percent_threshold = 95;
my $length_threshold = 25;
my $test = 0;
my $verbose = 0;
my $release = 5;

# do we automatically delete old alignments? Normally we want
# to let transferCurations do this
my $deleteOld = 0;

my $session = new Session;

GetOptions( 'percent=i'    => \$percent_threshold,
            'length=i'     => \$length_threshold,
            'test!'        => \$test,
            'delete!'      => \$deleteOld,
            'release=i'    => \$release,
           );

my $seq_name = $ARGV[0];

# some preliminaries to make sure we have a legit seq
my $seq = new Seq($session,{-seq_name=>$seq_name})->select;
   
my $insert_pos = $seq->insertion_pos;
$session->die("Sequence does not have an insertion position.")
                                   unless (defined($insert_pos));


my $bRS = new Blast_ReportSet($session,{-seq_name=>$seq->seq_name,
                                          -db=>'release'.$release.'_genomic'})->select;

# lets be careful and make sure that we are only dealing with the
# most recent blast run.

my %runIds = ();
my %hspIds = ();
map { $runIds{$_->run_id} = 1 } $bRS->as_list;
map { $hspIds{$_->id} = $_->run_id } $bRS->as_list;

# how many do we have?
$session->info("This sequence has multiple blast records.")
                                             if scalar(keys %runIds) > 1;

$session->die("There are no blast runs for this sequence.")
                                           unless (scalar(keys %runIds));

my $alignId = ( sort { $a <=> $b } keys %runIds )[-1];
$session->info("Aligning blast run id $alignId.");

# we want to see if we've already analyzed this blast set. We'll stop
# if we see that we have alignments based on this set.
my $saSet = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name,
                                           -seq_release=>$release})->select;

# so we can lookup
my %hit_hash;
map { $hit_hash{$_->id} = $_ } $bRS->as_list;

foreach my $align ($saSet->as_list) {
  my $s_insert;
  my $blast = $hit_hash{$align->hsp_id};
  # cases 1 and 2 are when the insert is at the end. This is simplest
  if( $insert_pos == $blast->query_begin) {
    $s_insert = $blast->subject_begin;
  } elsif ($insert_pos == $blast->query_end) {
    $s_insert = $blast->subject_end;
  } elsif( ($insert_pos > $blast->query_begin && $insert_pos < $blast->query_end) ||
           ($insert_pos < $blast->query_begin && $insert_pos > $blast->query_end) ) {
    # the next case in somewhere in the middle. We'll count matches to
    # find the bestest mapping
    $s_insert = $blast->subject_begin;
    my $q_pos = $blast->query_begin;
    my $q_inc = ($blast->query_end>$blast->query_begin)?+1:-1;
    foreach my $i (1..length($blast->query_align)) {
      $q_pos += $q_inc if substr($blast->query_align,$i-1,1) ne '-';
      $s_insert++ if substr($blast->subject_align,$i-1,1) ne '-';
      last if $q_pos==$insert_pos;
    }
    # the next 4 cases are beyond the end. Originally I extrapolated
    # for the reported position. Now I don't think that is correct.
    # (and others share that view.)
  } elsif ( $blast->query_end > $blast->query_begin && $insert_pos > $blast->query_end) {
    # beyond the + end with a + hit
    $s_insert = $blast->subject_end;
  } elsif ( $blast->query_end > $blast->query_begin && $insert_pos < $blast->query_begin ) {
    # beyond the - end with a + hit
    $s_insert = $blast->subject_begin;
  } elsif ( $blast->query_end < $blast->query_begin && $insert_pos < $blast->query_end) {
    # beyond the - end with a - hit
    $s_insert = $blast->subject_end;
  } elsif ( $blast->query_end < $blast->query_begin && $insert_pos > $blast->query_begin) {
    # beyond the + end with a - hit
    $s_insert = $blast->subject_begin;
  } else {
    $session->die("internal inconsistency with insert position.");
  }

  if ($s_insert == $align->s_insert) {
    $session->info("There is no update on the position for $seq_name.");
  } else {
    $session->info("Updating insertion postion for $seq_name from ",$align->s_insert," to $s_insert.");
    $align->s_insert($s_insert);
    $align->update;
  }
}

$session->exit();

exit(0);
