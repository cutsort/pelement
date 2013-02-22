package Phred_Seq;

=head1 Name

   Phred_Seq.pm A module for the encapsulation of Phred_Seq information

=head1 Usage

  use Phred_Seq;
  $Phred_Seq = new Phred_Seq($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use base 'DbObject';

sub read_file
{
  my $self = shift;
  my $file = shift;

  return unless ($file && -e $file);
  open(SEQ,$file) or return;

  my $seq;
  while (<SEQ>) {
    next if /^>/;
    chomp $_;
    s/\s+//g;
    $seq .= $_;
  }

  close(SEQ);

  return $self->seq($seq);
}

=head1 trimmed_seq

   Extracts the trimmed piece in the sequence. In a scalar context, this returns
   the sequence. In a vector context it returns the sequence and 2 labels, each
   either 'q' or 'v' indicating whether the sequence was quality or vector trimmed.

=cut
sub trimmed_seq
{
   my $self = shift;
   my $seq;
   my $start;
   my $start_flag;
   my $end_flag;
   if ( $self->v_trim_start ) {
      $start = $self->v_trim_start;
      $start_flag = 'v';
   } elsif ($self->q_trim_start) {
      $start = $self->q_trim_start;
      $start_flag = 'q';
   } else {
      # return nothing for undefined trimming
      return wantarray?('','',''):'';
   }

   my $extent;
   if ( $self->v_trim_end ) {
      # these will be ambiguous; the entired seq may be low quality.
      if ($start_flag eq 'q' && $self->v_trim_end < $self->q_trim_start) {
         return wantarray?('','',''):'';
      }
      if ($self->q_trim_end > $self->v_trim_end ) {
         $extent = $self->v_trim_end;
         $end_flag = 'v';
      } else {
         $extent = $self->q_trim_end;
         $end_flag = 'q';
      }
   } elsif ($self->q_trim_end) {
      $extent = $self->q_trim_end;
      $end_flag = 'q';
   } else {
      return wantarray?('','',''):'';
   }
   return wantarray?('','',''):'' if $extent <= $start;
   $seq = substr($self->seq,$start,$extent-$start);

   return wantarray?($seq,$start_flag,$end_flag):$seq;
}

1;
