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

=head1 to_fasta(filename,{options})

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

=head1 rev_comp

  Callable as an object method or as a static

=cut
sub rev_comp
{
  my $self = shift;
  my $seq = (ref($self))?$self->sequence:$self;

  $seq = join('',reverse(split(//,$seq)));
  $seq =~ tr/ACGTacgt/TGCAtgca/;

  if ( ref($self) ) {
    $self->sequence($seq);
    return $self;
  } else {
    return $seq;
  }
}

=head1 Parsing routines

  The remainding routines are intended as parsing routines; they do not
  require db retrieval but are based on parsing the input

=cut
=head1 parse

  Returns the strain, end, and qualifiers. This is not stored in the db
  but is deduced from the sequence name

  This can be called on an object or called as a static routine:
     $seq->parse()
  or
     Seq::parse($seq_name)

=cut
sub parse
{
  my $self = shift;
  return(Seq::strain($self),Seq::end($self),Seq::qualifier($self));
}

=head1 strain

  Returns the strain designator. This is not stored in the db
  but is deduced from the sequence name

  This can be called on an object or called as a static routine:
     $seq->strain()
  or
     Seq::strain($seq_name)

  return values are '5', '3' or 'b' for a composite

=cut

sub strain
{
  my $self = shift;
  my $name = (ref($self))?$self->seq_name:$self;

  if ( $name =~ /([^-]*)-[35].*/ ) {
    return $1;
  } elsif ( $name !~ /-/ ) {
    return $name;
  } else {
    return '';
  }
}

=head1 end

  Returns the end designator. This is not stored in the db
  but is deduced from the sequence name

  This can be called on an object or called as a static routine:
     $seq->end()
  or
     Seq::end($seq_name)

  return values are '5', '3' or 'b' for a composite

=cut
sub end
{
  my $self = shift;

  my $name = (ref($self))?$self->seq_name:$self;

  if ( $name =~ /.*-([35]).*/ ) {
    return $1;
  } else {
    return 'b';
  }
}

=head1 qualifier

  Returns the qualifier designator. This is not stored in the db
  but is deduced from the sequence name

  This can be called on an object or called as a static routine:
     $seq->qualifier()
  or
     Seq::qualifier($seq_name)

  return values are nothing, a number for obsoleted seqs, or a letter
  code for unconfirmed recheck and the like.

=cut
sub qualifier
{
  my $self = shift;

  my $name = (ref($self))?$self->seq_name:$self;

  if ( $name =~ /[^-]*-[35]\.?(.*)/ ) {
    return $1;
  } elsif ( $name =~ /[^-]*\.(.*)/ ) {
    return $1;
  } else {
    return '';
  }
}

1;
