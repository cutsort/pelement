package Seq;

=head1 Name

   Seq.pm A module for the encapsulation of seq information

=head1 Usage

  use Seq;
  $seq = new Seq($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use DbObject;

=head1

  to_fasta(filename,{options})

  Write the current sequence to a fasta file. 
  An optional hashref with keys -name and -desc can
  be used to embellish the header.

=cut
sub to_fasta
{
  my $self = shift;
  my $filename = shift;
  my $args = shift || {};

  open(FIL,">$filename") or 
        ($self->{_session}->error("Cannot open file $filename: $!") and exit(1));

  if (!exists($args->{-name}) ) {
     $args->{-name} = $self->seq_name;
  }
  my $header = ">".$args->{-name};
  $header .= " ".$args->{-desc} if exists($args->{-desc});
  print FIL "$header\n";
  my $output = $self->sequence;
  $output =~ s/(.{50})/$1\n/g;
  $output .= "\n";
  $output =~ s/\n\n/\n/;
  print FIL $output;
  close(FIL);

  $self->{fasta} = $filename;
}

1;
