=head1 Name

   Sequence.pm  A module for manipulating sequences

=head1 Usage

   use Sequence;
   $sequence = new Sequence([options])

=head1 Options

   -nodb  Do not open the database

=cut

package Sequence;

use strict;
use Pelement;
use Getopt::Long;
use DBI;

=head1 Public Methods

=cut

sub new 
{
  my $class = shift;

  my $name = "Sequence";
  my $fasta = "";
  my $seq = "";
  my $desc = "";

  # we'll look for a hash of optional arguments
  my $args = shift;
  if ($args) {
    $name = $args->{-name} if exists($args->{-name});
    $fasta = $args->{-fasta} if exists($args->{-fasta});
    $seq = $args->{-seq} if exists($args->{-seq});
    $desc = $args->{-desc} if exists($args->{-desc});
  }

  my $self = {"name" =>$name,
              "fasta"=>$fasta,
             };

  return bless $self, $class;
}

=head1
  read_from_db
  write_to_db

  seqIO to the database

=cut

sub read_from_db
{
  my $self = shift;
  my $dbh = shift;

  return unless $dbh;
  return unless $self->get_name();
  
  my $sql = qq(select sequence from seq where seq_name=).
            $dbh->quote($self->get_name());
  my $st = $dbh->prepare($sql);
  $st->execute();
  my ($seq) = $st->fetchrow_array();
  $st->finish();
  $self->{seq} = $seq;
  return $seq;
  
}
sub write_to_db
{
}
=head1

  write_to_fasta(filename)
  read_from_fasta(filename)

  Write the current sequence to a fasta file. Since the current sequence
  exists as a fasta file, we'll preserve that name in the object

=cut
sub write_to_fasta
{
  my $self = shift;
  my $filename = shift;

  open(FIL,">$filename") or die "Cannot open file $filename.";
  print FIL ">".$self->{name}." ".$self->{desc}."\n";
  my $output = $self->{seq};
  $output =~ s/(.{50})/$1\n/g;
  $output .= "\n";
  $output =~ s/\n\n/\n/;
  print FIL $output;
  close(FIL);

  $self->{fasta} = $filename;
}

sub read_from_fasta
{
}

sub get_fasta_file
{
  my $self = shift;
  return $self->{fasta};
}

sub get_name
{
  my $self = shift;
  return $self->{name};
}
sub set_name
{
  my $self = shift;
  my $name = shift;
  my $old_name = $self->get_name;
  $self->{name} = $name;
  return $old_name;
}

1;
