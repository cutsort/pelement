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
use DbObject;

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


1;

