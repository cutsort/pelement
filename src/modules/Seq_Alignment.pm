package Seq_Alignment;

=head1 Name

   Seq_Alignment.pm A module for the encapsulation of Seq_Alignment information

=head1 Usage

  use Seq_Alignment;
  $Seq_Alignment = new Seq_Alignment($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use Blast_Report;
use Seq;
use DbObject;

=head1 from_Blast_Report

  generate a new sequence alignment from a blast_report object

=cut

sub from_Blast_Report
{
   my $self = shift;
   my $bR = shift;

   $self->session->error("Not A Report","$bR is not a Blast_Report object.")
                                             unless ref($bR) eq "Blast_Report";

   # and what is the sequence object for this query?
   my $seq = new Seq($self->session,{seq_name=>$bR->seq_name})->select_if_exists();
   $self->session->error("No Sequence object",
                  "Cannot locate sequence with name ".$bR->seq_name.".") unless $seq;
   my $s_insert = 0;
   if ( $bR->query_begin == $seq->insertion_pos ) {
      $s_insert = $bR->subject_begin;
   } elsif ($bR->query_end == $seq->insertion_pos) {
      $s_insert = $bR->subject_end;
   } elsif ( ( ($seq->insertion_pos > $bR->query_begin) &&
               ($seq->insertion_pos < $bR->query_end) )  ||
             ( ($seq->insertion_pos < $bR->query_begin) &&
               ($seq->insertion_pos > $bR->query_end) ) ) {
      $s_insert = $bR->subject_begin;
      my $q_pos = $bR->query_begin;
      my $q_inc = ($bR->query_end>$bR->query_begin)?+1:-1;
      foreach my $i (1..length($bR->query_align)) {
         $q_pos += $q_inc if substr($bR->query_align,$i-1,1) ne '-';
         $s_insert++ if substr($bR->subject_align,$i-1,1) ne '-';
         last if $q_pos==$seq->insertion_pos;
      }
   } elsif ( $bR->query_end > $bR->query_begin && $seq->insertion_pos > $bR->query_end) {
      # beyond the + end with a + hit
      $s_insert = $bR->subject_end + ($seq->insertion_pos - $bR->query_end);
   } elsif ( $bR->query_end > $bR->query_begin && $seq->insertion_pos < $bR->query_begin ) {
      # beyond the - end with a + hit
      $s_insert = $bR->subject_begin - ($bR->query_begin - $seq->insertion_pos);
   } elsif ( $bR->query_end < $bR->query_begin && $seq->insertion_pos < $bR->query_end) {
      # beyond the - end with a - hit
      $s_insert = $bR->subject_end + ($bR->query_end - $seq->insertion_pos);
   } elsif ( $bR->query_end < $bR->query_begin && $seq->insertion_pos > $bR->query_begin) {
      # beyond the + end with a - hit
      $s_insert = $bR->subject_begin - ($seq->insertion_pos - $bR->query_begin);
   } else {
      $self->session->error("Internal","Internal inconsistency with insert position.");
   }

   $self->seq_name($seq->seq_name);
   $self->scaffold($bR->name);
   $self->p_start($bR->query_begin);
   $self->p_end($bR->query_end);
   $self->s_start($bR->subject_begin);
   $self->s_end($bR->subject_end);
   $self->s_insert($s_insert);
   $self->hsp_id($bR->id);

   return $self;
}

  
  


   



1;
