#!/usr/local/bin/perl -I../modules

=head1 NAME

  alignSeq.pl consolidate blast results into an alignment entry

=head1 USAGE

  alignSeq.pl [options] <seq_name>

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

# a configurable parameter of whether to extrapolate the insertion
# position beyond the HSP. If false, the last position of the HSP
# is reported. We probably should never change this
my $extrapolate = 0;

# do we automatically delete old alignments? Normally we want
# to let transferCurations do this
my $deleteOld = 0;

GetOptions( 'percent=i'    => \$percent_threshold,
            'length=i'     => \$length_threshold,
            'test!'        => \$test,
            'verbose!'     => \$verbose,
            'extrapolate!' => \$extrapolate,
            'delete!'      => \$deleteOld,
           );

my $session = new Session;
$session->log_level($Session::Verbose) if $verbose;

my $seq_name = $ARGV[0];

# some preliminaries to make sure we have a legit seq
my $seq = new Seq($session,{-seq_name=>$seq_name})->select;
my $seq_length = length($seq->sequence);

$session->die("Sequence length is below the threshold.")
                       if ($seq_length < $length_threshold );
   
my $insert_pos = $seq->insertion_pos;
$session->die("Sequence does not have an insertion position.")
                                   unless (defined($insert_pos));


my $bRS = new Blast_ReportSet($session,{-seq_name=>$seq->seq_name,
                                          -db=>'release3_genomic'})->select;

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
my $saSet = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;

# have we already done this? Only check if we're not deleting them anyway
unless ($deleteOld) {
   map { $session->die("Latest blast run has already been aligned") if
                        $hspIds{$_->hsp_id} == $alignId } $saSet->as_list;
}

# wrap everything in a transaction. We don't expect anyone to be
# modifying these tables, but let's be careful.
$session->db_begin;

# now remove old if requested.
$saSet->delete if $deleteOld;

# a container for the new seq alignments.
my $nsaSet = new Seq_AlignmentSet($session);

foreach my $bH ($bRS->as_list) {
   my $id = $bH->id;
   my $name = $bH->name;
   my $percent = $bH->percent;
   my $match = $bH->match;
   my $length = $bH->length;
   my $query_begin = $bH->query_begin;
   my $query_end = $bH->query_end;
   my $subject_begin = $bH->subject_begin;
   my $subject_end = $bH->subject_end;
   my $q_align = $bH->query_align;
   my $s_align = $bH->subject_align;
   
   next if $percent < $percent_threshold;
   next if $length < $length_threshold;
   
   if ( ($length > $seq_length-10 && $length < $seq_length+10 ) &&
        ($seq_length > 100  || $length/$seq_length >= .85)       ) {

      # here is the mapping of the insertion position onto the genomic
      # we want to find the exact location of the insert within the hsp
      # make sure that the insert is within the hit first
      # 100% matches are trivial and we can do it be adding. But otherwise
      # we need to count into the alignments for the positions.
      # this can probably be made more compact, but this makes the
      # mapping steps explicit.
      # if the insert is exactly at the end of the hsp, this is
      # easy
      my $s_insert = 0;
      # cases 1 and 2 are when the insert is at the end. This is simplest
      if( $insert_pos == $query_begin) {
         $s_insert = $subject_begin;
      } elsif ($insert_pos == $query_end) {
         $s_insert = $subject_end;
      # the next case in somewhere in the middle. We'll count matches to
      # find the bestest mapping
      } elsif( ($insert_pos > $query_begin && $insert_pos < $query_end) ||
               ($insert_pos < $query_begin && $insert_pos > $query_end) ) {
         $s_insert = $subject_begin;
         my $q_pos = $query_begin;
         my $q_inc = ($query_end>$query_begin)?+1:-1;
         foreach my $i (1..length($q_align)) {
            $q_pos += $q_inc if substr($q_align,$i-1,1) ne '-';
            $s_insert++ if substr($s_align,$i-1,1) ne '-';
            last if $q_pos==$insert_pos;
         }
      # the next 4 cases are beyond the end. Originally I extrapolated
      # for the reported position. Now I don't think that is correct.
      # (and others share that view.)
      } elsif ( $query_end > $query_begin && $insert_pos > $query_end) {
         # beyond the + end with a + hit
         $s_insert = $subject_end;
         $s_insert = $subject_end + ($insert_pos - $query_end)
                                                      if ($extrapolate)
      } elsif ( $query_end > $query_begin && $insert_pos < $query_begin ) {
         # beyond the - end with a + hit
         $s_insert = $subject_begin;
         $s_insert = $subject_begin - ($query_begin - $insert_pos)
                                                      if ($extrapolate)
      } elsif ( $query_end < $query_begin && $insert_pos < $query_end) {
         # beyond the - end with a - hit
         $s_insert = $subject_end;
         $s_insert = $subject_end + ($query_end - $insert_pos)
                                                      if ($extrapolate)
      } elsif ( $query_end < $query_begin && $insert_pos > $query_begin) {
         # beyond the + end with a - hit
         $s_insert = $subject_begin;
         $s_insert = $subject_begin - ($insert_pos - $query_begin)
                                                      if ($extrapolate)
      } else {
         $session->die("internal inconsistency with insert position.");
      }

      my $seqA = new Seq_Alignment($session,
                                   {-seq_name => $seq_name,
                                    -scaffold => $name,
                                    -p_start  => $query_begin,
                                    -p_end    => $query_end,
                                    -s_start  => $subject_begin,
                                    -s_end    => $subject_end,
                                    -s_insert => $s_insert,
                                    -status   => 'multiple',
                                    -hsp_id   => $id});
      $nsaSet->add($seqA);
   }
}

  
my $numHits = $nsaSet->count;
if( $numHits == 1 ) {
   $session->verbose("Declaring this alignment unique.");
   # map over the one element in the alignment
   map {$_->status('unique') } $nsaSet->as_list;
}

# now do the insert
$nsaSet->insert;

if ($test) {
   $session->db_rollback;
} else {
   $session->db_commit;
}

$session->exit();

exit(0);
