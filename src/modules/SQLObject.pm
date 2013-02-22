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
  my $bind_params;
  if (ref($arg) eq '') {
    # we passed SQL
    $sql = $arg;
  } else {
    # we passed an object
    $sql = $arg->{_sql};
    $cols = $arg->{_cols};
    $bind_params = $arg->{_bind_params};
  }

  my $self = {
    _sql => $sql,
    _cols => $cols,
    _bind_params => $bind_params||[],
    _class => $class,
    _session => $session,
  };

  initialize_self($self,@_);
  return bless $self,$class;
}

sub initialize_self {
  my $self = shift;
  # make the internals (column names...) if they were not passed
  return if $self->{_cols} 
    && (ref($self->{_cols}) eq 'ARRAY') 
    && @{$self->{_cols}};
  $self->{_bind_params} = @_ ? \@_ : [];

  # rather than trying to parse the SQL, we'll let the server
  # do that work with a trivialized statement.
  my $sql_code = $self->{_sql};
  $sql_code =~ s/;\s*$//;
  my $trivialized_sql = "SELECT * FROM ( $sql_code ) __sql_table WHERE FALSE";
  my $sql = $self->{_session}->db->prepare($trivialized_sql);
  $sql->execute(@{$self->{_bind_params}});
  $self->{_session}->die("$DBI::errstr in processing SQL: ".$self->{_sql})
    if $self->{_session}->db->state;

  $self->{_cols} = \@{$sql->{NAME}};
  $sql->finish;
  return;
}

sub select_if_exists { 
  return $_[0]->select({-onnull=>'ignore'});
} 

sub select
{
  my $self = shift;
  my $session = $self->{_session} 
    || die "Session handle required db selection";
  # do we ignore warnings?
  my $ignoreWarnings = shift;

  my %errorOptions = ( 
    -onnull => 'warn',
    -onmany => 'warn',
  );

  # if $ignoreWarnings is a reference, it may have detailed
  # behavior of what to do
  if (ref($ignoreWarnings) eq 'HASH') {
    map { $errorOptions{$_} = $ignoreWarnings->{$_} } keys %$ignoreWarnings;
  } 
  elsif ($ignoreWarnings) {
    $errorOptions{-onnull} = 'ignore';
  }

  my $sql = $self->{_sql};
  $session->sqlverbose("SQL: $sql.");
  my $st = $session->db->prepare($sql);
  $st->execute(@_ ? @_ : @{$self->{_bind_params}});
  $session->die("$DBI::errstr in processing SQL: $sql")
    if $session->db->state;

  my $href = $st->fetchrow_hashref();
  if (!$href) {
    # at least make the column records.
    $self->{$_} = undef for @{$self->{_cols}};

    if ($errorOptions{-onnull} eq 'ignore') {
      $session->verbose("SQL $sql returned no object. Ignoring.");
    } 
    elsif ( $errorOptions{-onnull} eq 'die' ) {
      $session->die("SQL $sql returned no object.");
    } 
    else {
      $session->warn("SQL $sql returned no object.");
    }
    return $self;
  }
  $self->{$_} = $href->{$_} for @{$self->{_cols}};
  $href = $st->fetchrow_hashref();

  if ($href) {
    if ($errorOptions{-onmany} eq 'ignore') {
      $session->verbose("SQL $sql returned multiple objects. Ignoring.");
    } 
    elsif ( $errorOptions{-onmany} eq 'die' ) {
      $session->die("SQL $sql returned multiple objects.");
    } 
    else {
      $session->warn("SQL $sql returned multiple objects.");
    }
  }
  $st->finish;
  return $self;
}

sub db_exists
{
  my $self = shift;
  my $sql_code = $self->{_sql};
  $sql_code =~ s/;\s*$//;
  my $trivialized_sql = "SELECT EXISTS(SELECT * FROM ( $sql_code ) __sql_table)";
  return $self->session->db->select_value($trivialized_sql);
}
  

sub session {
  my $self = shift;
  return $self->{_session};
}

sub AUTOLOAD
{
  my $self = shift;
  croak "$self is not an object." unless ref($self);
  my $name = $SQLObject::AUTOLOAD;

  $name =~ s/.*://;
  if (!exists( $self->{$name})) {
     $self->{_session}->die("$name is not a method for ".ref($self).".");
  }
  $self->{$name} = shift @_ if @_;
  return $self->{$name};
}

=head2 formatList

Given a list, convert it into a SQL-escaped list of quoted items.

=cut

sub formatList
{
  my $session = shift;
  my $list = shift;
  $list = [$list] if !ref($list);
  my @result = map {$session->db->quote($_)} @$list;
  return "(".(join(",",@result)||'NULL').")";
}

=head1 DESTROY

  to prevent AUTOLOAD from being called.

=cut

sub DESTROY {};

1;

