package GenBank_Submission_Info;

=head1 Name

   GenBank_Submission_Info.pm A module for the encapsulation of genbank submission information

=head1 Usage

  use GenBank_Submission_Info;
  $gb = new GenBank_Submission_Info($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

  In addition to the fields stored in the db, there are some additional things kept in the object

=cut

use Pelement;
use PCommon;
use PelementDBI;
use DbObject;

=head1 new

  The default constructor, with some additional fields.

=cut

sub new
{
   my $class = shift;
 
   # SUPER appears to be caught by AUTOLOAD. be explicit instead.
   my $self = DbObject::new($class,@_);
   $self->{type} = 'GSS';
   $self->{status} = 'New';
   $self->{dbname} = 'BDGP_INS';
   $self->{dbxref} = '';
   $self->{gss} = '';
   $self->{sequence} = '';
   $self->{end} = '';
   $self->{insertion_pos} = 'unknown';
   return $self;
}

sub add_seq
{
   my $self = shift;
   my ($end,$seq,$pos) = @_;

   $self->end(shift);
   $self->sequence(shift);
   $self->insertion_pos(shift);

   return $self;

}

=head1 print

  Generate output suitable for a mailed record.

=cut

sub print
{
  my $self = shift;

  my $output;
  map {$output .= uc($_).": ".$self->$_."\n"} qw(type status cont_name citation library);

  $output .= 'GSS#: '.$self->gss."\n";
  $output .= "PUBLIC: \n";

  map {$output .= uc($_).": ".$self->$_."\n"} qw(class p_end dbname dbxref);

  # the comment needs special handling.
  my $comment .= $self->comment;
  my $l = length($self->sequence);
  my $in = $self->insertion_pos;
  $comment =~ s/<SEQLENGTH>/$l/sg;
  $comment =~ s/<SEQINSERT>/$in/sg;
  $comment =~ s/(.+)/~$1~/g;
  $output .= "COMMENT:\n$comment\n";
  my $seq = $self->sequence;
  $seq =~ s/(.{50})/$1\n/g;
  $seq .= "\n";
  $seq =~ s/\n\n/\n/;
  $output .= "SEQUENCE:\n$seq||";

  return $output;

}
  
1;

