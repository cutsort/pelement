=head1 Name

  SQLObjectSet.pm

  A class for modules that use explicit SQL to create objects.

  This is a pretty rudimentary implemetation; only "simple" sql will work

=cut

package SQLObjectSet;

use Exporter;
use PCommon;
use Session;

use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(select add unshift count session as_list as_list_ref);

=head1 new

  The constructor. This requires either a scalar SQL to construct the
  columns, or a base single-object class to use to crib the columns from

=cut
sub new
{
  my $class = shift;
  my $session = shift || die "Session argument required.";
  my $arg = shift || $session->die("SQL or object required for to construct $class.");

  my $sql;
  my $cols;
  if (ref($arg) eq '') {
    # we passed SQL
    $sql = $arg;
  } else {
    # we passed an object
    $sql = $arg->{_sql};
    $cols = $arg->{_cols};
  }

  # the base class name is the class with Set stripped off
  (my $base = $class) =~ s/Set$//;
  my $self = {     _sql => $sql,
                  _cols => $cols,
                  _base => $base,
               _session => $session };

  initialize_self($self,@_);
  return bless $self,$class;

}

sub initialize_self
{
  my $self = shift;
  # make the internals (column names...) if they were not passed
  return if $self->{_cols} && (ref($self->{_cols}) eq 'ARRAY') && @{$self->{_cols}};

  # rather than trying to parse the SQL, we'll let the server
  # do that work with a trivialized statement.


  # this is the part that may need work; we're adding a 'where false' as a condition
  # it comes before the 'group by...' if that exists.
  my $trivialized_sql = $self->{_sql};
  if ($trivialized_sql =~ /\swhere\s/) {
    if ($trivialized_sql =~ /\sgroup\s/s) {
      $trivialized_sql =~ s/(\swhere\s).*?(\sgroup\s.*)/$1 false $2/s;
    } else {
      $trivialized_sql =~ s/(\swhere\s).*/ where false/s;
    }
  } else {
    $trivialized_sql =~ s/(\sgroup\s.*)?/s where false $1/;
  }
  my $sql = $self->{_session}->db->prepare($trivialized_sql);
  $sql->execute;
  $self->{_session}->die("$DBI::errstr in processing SQL: ".$self->{_sql})
                   if $self->{_session}->db->state;
  $self->{_cols} = \@{$sql->{NAME}};
  $sql->finish;

}

sub select
{
  my $self = shift;

  my $sessionHandle = $self->{_session} || die "Session handle required db selection";

  # do we need to load a class for the base object?
  my $class = $self->{_base};
  eval { require $class.'.pm'};

  my $sql = $self->{_sql};
  $sessionHandle->sqlverbose("SQL: $sql.");
  my $st = $sessionHandle->db->prepare($sql);
  $st->execute;
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

=head1 session

  returns the session object

=cut
sub session
{
  return shift->{_session};
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
  return scalar(@{$self->{_objects}})||0;
}

1;
