=head1 Name

  SQLObject.pm

  A class for modules that use explicit SQL to create one object.

  We generate an object based on the results of an SQL query. Since this
  is intended for complex SQL - not a single record from a single table - only
  selects are implemented.

  This is a pretty rudimentary implemetation; only "simple" sql will work.
  I'm thinking this would only be for reports (i.e. joins with aggregrates)
  and not need to support inserts, deletes or updates.

=cut

package SQLObject;

use PCommon;
use Session;

use Carp;

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

  my $self = {     _sql => $sql,
                  _cols => $cols,
                 _class => $class,
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
  my $sql = $self->{_session}->db->prepare($self->{_sql}.
                 (($self->{_sql}=~/ where /)?' and false':' where false'));
  $sql->execute;
  $self->{_session}->die("$DBI::errstr in processing SQL: ".$self->{_sql})
                   if $self->{_session}->db->state;
  $self->{_cols} = \@{$sql->{NAME}};
  $sql->finish;

  return;
}

sub select
{
  my $self = shift;
  my $sessionHandle = $self->{_session} || die "Session handle required db selection";
  # do we ignore warnings?
  my $ignoreWarnings = shift;

  my %errorOptions = ( -onnull => 'warn',
                       -onmany => 'warn' );

  # if $ignoreWarnings is a reference, it may have detailed
  # behavior of what to do
  if (ref($ignoreWarnings) eq 'HASH') {
    map { $errorOptions{$_} = $ignoreWarnings->{$_} } keys %$ignoreWarnings;
  } elsif ($ignoreWarnings) {
    $errorOptions{-onnull} = 'ignore';
  }

  my $sql = $self->{_sql};
  $sessionHandle->sqlverbose("SQL: $sql.");
  my $st = $sessionHandle->db->prepare($sql);
  $st->execute;
  $sessionHandle->die("$DBI::errstr in processing SQL: $sql")
                                       if $sessionHandle->db->state;
  my $href = $st->fetchrow_hashref();
  unless ($href) {
    if ($errorOptions{-onnull} eq 'ignore') {
      $sessionHandle->verbose("SQL $sql returned no object. Ignoring.");
    } elsif ( $errorOptions{-onnull} eq 'die' ) {
      $sessionHandle->die("SQL $sql returned no object.");
    } else {
      $sessionHandle->warn("SQL $sql returned no object.");
    }
    return $self;
  }

  map { $self->{$_} = $href->{$_} } @{$self->{_cols}};

  $href = $st->fetchrow_hashref();

  if ($href) {
    if ($errorOptions{-onmany} eq 'ignore') {
      $sessionHandle->verbose("SQL $sql returned multiple objects. Ignoring.");
    } elsif ( $errorOptions{-onmany} eq 'die' ) {
      $sessionHandle->die("SQL $sql returned multiple objects.");
    } else {
      $sessionHandle->warn("SQL $sql returned multiple objects.");
    }
  }

  $st->finish;
  return $self;

}

sub AUTOLOAD
{
  my $self = shift;
  croak "$self is not an object." unless ref($self);
  my $name = $AUTOLOAD;

  $name =~ s/.*://;
  if (! exists( $self->{$name} ) ) {
     $self->{_session}->die("$name is not a method for ".ref($self).".");
  }
  $self->{$name} = shift @_ if ( @_ );
  return $self->{$name};
}

=head1 DESTROY

  to prevent AUTOLOAD from being called.

=cut
sub DESTROY {};

1;
