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
#use BlastHsps;
#use BlastInterface;
use Files;
use strict;
no strict 'refs';

my $percent_threshold = 95;
my $length_threshold = 25;

my $session = new Session({-log_level=>$Session::Verbose});

my $seq_name = $ARGV[0];

# a configurable parameter of whether to extrapolate the insertion
# position beyond the HSP. If false, the last position of the HSP
# is reported.
my $extrapolate = 0;

# todo: change this in to a BlastInterface object
my $sql = qq(select blast_hsp.id,name,score,percent,match,length,query_begin,
             query_end,subject_begin,subject_end,strand,query_align,subject_align
             from blast_run, blast_hit,blast_hsp where
             blast_run.seq_name=).$session->db->quote($seq_name).
          qq( and blast_run.id=run_id and blast_hit.id=hit_id
             and blast_run.db='release3_genomic'
             order by score desc);

my @records = ();
$session->db->select($sql,\@records);

my $seq = new Seq($session,{-seq_name=>$seq_name})->select;

my $seq_length = length($seq->sequence);

if ($seq_length < $length_threshold ) {
   $session->log($Session::Info,"Sequence length is below the threshold.");
   $session->exit;
   exit(0);
}

my $insert_pos = $seq->insertion_pos;

# out with the old
my $sSet = new Seq_AlignmentSet($session,{-seq_name=>$seq_name})->select;
map { $_->delete } $sSet->as_list;


# todo: change this into a looping over BlastHsp objects
#
$sql = '';

while (@records) {
   my ($id,$name,$score,$percent,$match,$length,$query_begin,$query_end,
             $subject_begin,$subject_end,$strand,$q_align,$s_align) = splice(@records,0,13);

   next if $percent < $percent_threshold;
   next if $length < $length_threshold;
   
   if ( ($length > $seq_length-10 && $length < $seq_length+10 ) &&
        # todo: change this into an alignment object.
        ($seq_length > 100  || $length/$seq_length >= .85) ) {

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
         die "internal inconsistency with insert position.";
      }

      $sql .= "insert into seq_alignment (seq_name,scaffold,p_start,p_end,s_start,";
      $sql .= "s_end,s_insert,status,hsp_id) values (";
      foreach my $var ($seq_name,$name,$query_begin,$query_end,$subject_begin,
                                                         $subject_end,$s_insert,'multiple',$id) {
         $sql .= $session->db->quote($var).",";
      }
      $sql =~ s/,$/);/;
   }
}

  
$session->log($Session::Verbose,"SQL: $sql.");
$session->db->do($sql) if $sql;

my $numHits = $session->db->select_value("select count(seq_name) from seq_alignment where ".
                                         "seq_name='$seq_name'");
if( $numHits == 1 ) {
   $session->log($Session::Verbose,"Declaring this alignment unique.");
   $session->db->do(qq(update seq_alignment set status='unique' where
                       seq_name='$seq_name' and status='multiple'));
}

$session->exit();

exit(0);
