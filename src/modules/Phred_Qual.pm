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
use DbObject;

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


1;

