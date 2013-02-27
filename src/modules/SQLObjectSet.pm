=head1 Name

  SQLObjectSet.pm

  A class for modules that use explicit SQL to create objects.

  This is a pretty rudimentary implemetation; only "simple" sql will work

=cut

package SQLObjectSet;

use SQLObject;
use Exporter;
use Session;
use Carp;
use strict;
use warnings;

=head1 new

  The constructor. This requires either a scalar SQL to construct the
  columns, or a base single-object class to use to crib the columns from

=cut
sub new
{
  my $class = shift;
  my $session = shift 
    || die "Session argument required.";
  my $arg = shift 
    || $session->die("SQL or object required for to construct $class.");

  my $sql;
  my $cols;
  if (ref $arg eq '') {
    $sql = $arg; 
    $arg = shift;
  }
  else {
    $sql = $arg->{_sql}; 
    $sql = $arg->{_cols}; 
  }

  (my $base = $class) =~ s/Set$//;
  my $self = {  
    _sql => $sql,
    _cols => $cols,
    _base => $base,
    _objects => [],
    _session => $session 
  };

  SQLObject::initialize_self($self,@_);
  return bless $self,$class;
}

sub select
{
  my $self = shift;

  my $sessionHandle = $self->{_session} || die "Session handle required db selection";

  # do we need to load a class for the base object?
  my $class = $self->{_base};
  eval { require $class.'.pm'};
  if ($@) {
    eval "{package $class; use base 'SQLObject'; }";
  }

  my $sql = $self->{_sql};
  $sessionHandle->sqlverbose("SQL: $sql.");
  my $st = $sessionHandle->db->prepare($sql);
  $st->execute(@_ ? @_ : @{$self->{_bind_params}});
  $sessionHandle->die("$DBI::errstr in processing SQL: $sql")
                                       if $sessionHandle->db->state;
  while ( my $href = $st->fetchrow_hashref() ) {
    my $new_self = $class->new($sessionHandle,$self);
    map { $new_self->{$_} = $href->{$_} } @{$self->{_cols}};
    push @{$self->{_objects}} ,$new_self;

  }
  $st->finish;
  return $self;
}

sub as_list
{
  return @{shift->{_objects}};
}

sub as_list_ref
{
  return shift->{_objects};
}

=head1 add

  Add an object to the set.

=cut
sub add
{
   my $self = shift;
   my $new_obj = shift;

   $self->{_session}->die("$new_obj is not a ".$self->{_table}." object.")
                                     unless ref($new_obj) eq $self->{_table};

   push @{$self->{_objects}}, $new_obj;
}

=head1 unshift

  Kinda like add, but puts it at the top of the list

=cut

sub unshift
{
   my $self = shift;
   my $new_obj = shift;

   $self->{_session}->die("$new_obj is not a ".$self->{_table}." object.")
                                     unless ref($new_obj) eq $self->{_table};

   unshift @{$self->{_objects}}, $new_obj;
}

=head1 count

  Hommany object we got. Not a DB query!

=cut

sub count
{
  my $self = shift;
  return scalar(@{$self->{_objects}});
}

1;
