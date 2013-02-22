package Phred_Qual;

=head1 Name

   Phred_Qual.pm A module for the encapsulation of Phred_Qual information

=head1 Usage

  use Phred_Qual;
  $Phred_Qual = new Phred_Qual($session,{-key1=>val1,-key2=>val2...});

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
  open(QUAL,$file) or return;
  
  my $qual;
  while (<QUAL>) {
    next if /^>/;
    chomp $_;
    $qual .= $_;
  }

  $qual =~ s/\s+/ /g;

  close(QUAL);
  return $self->qual($qual);
}

=head1 trimmed_qual

   Extracts the trimmed piece in the sequence. In a scalar context, this returns
   the sequence. In a vector context it returns the sequence and 2 labels, each
   either 'q' or 'v' indicating whether the sequence was quality or vector trimmed.

=cut
sub trimmed_qual
{
   my $self = shift;
 
   my $baseSeq = shift || new Phred_Seq($self->{_session},{-id=>$self->phred_id})->select;

   my $qual;
   my $start;
   my $start_flag;
   my $end_flag;
   if ( $baseSeq->v_trim_start ) {
      $start = $baseSeq->v_trim_start;
      $start_flag = 'v';
   } elsif ($baseSeq->q_trim_start) {
      $start = $baseSeq->q_trim_start;
      $start_flag = 'q';
   } else {
      # return nothing for undefined trimming
      return wantarray?('','',''):'';
   }

   my $extent;
   if ( $baseSeq->v_trim_end ) {
      # these will be ambiguous; the entired seq may be low quality.
      if ($start_flag eq 'q' && $baseSeq->v_trim_end < $baseSeq->q_trim_start) {
         return wantarray?('','',''):'';
      }
      if ($baseSeq->q_trim_end > $baseSeq->v_trim_end ) {
         $extent = $baseSeq->v_trim_end;
         $end_flag = 'v';
      } else {
         $extent = $baseSeq->q_trim_end;
         $end_flag = 'q';
      }
   } elsif ($baseSeq->q_trim_end) {
      $extent = $baseSeq->q_trim_end;
      $end_flag = 'q';
   } else {
      return wantarray?('','',''):'';
   }
 
   # final consistency check
   return wantarray?('','',''):'' unless $extent > $start;

   $qual = join(' ',(split(/\s+/,$self->qual))[$start..$extent-1]);

   return wantarray?($qual,$start_flag,$end_flag):$qual;
}

1;
