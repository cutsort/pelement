=head1 NAME

   PelementDBI

   The overloaded DBI interface with some Pelement specific processing
   methods.

=head1 USAGE

   use PelementDBI;
   $db = new PelementDBI($session,$db_connect_string);
   $db->do($sql);

=head1 REQUIRED PARAMETERS

   $session an open processing session
   $db_connect_string a DBI valid connect string

=head1 OPTIONS

=cut

package PelementDBI;
use DBI;

=head1 PUBLIC METHODS

=head2 new

   A thin layer on top of DBI->connect in which the session id is
   kept.

=cut
sub new
{
  my $class = shift;
  my $session = shift || die "Session required for DB connection.";
  my $dbh = DBI->connect(@_);

  $session->exit("Cannot connect to database.") unless $dbh;

  # handle errors ourselves. (need to do so to get them in the log files).
  $dbh->{RaiseError} = 0;

  # eventually, we want to suppress printing errors. but leave this
  # on until we're certain we got them all.

  ##$dbh->{PrintError} = 0;


  # here is how we keep a handle on private functions
  my $self = {session => $session,
             dbh     => $dbh, 
            };
  return bless $self, $class;
}

=head2 select_value

   A convenience routine for selecting a single value with a sql select

=cut

sub select_value
{
  my $self = shift;
  my $sql = shift;

  my $session = $self->{session};

  $session->log($Session::Verbose,"SQL: $sql");

  my $st = $self->{dbh}->prepare($sql);
  $st->execute();
  $row = $st->fetchrow_arrayref();
  $session->log($Session::Error,"select_value returns more than 1 column.")
                 if scalar(@$row) > 1;
  $session->log($Session::Error,"select_value did not return any column.")
                 if scalar(@$row) == 0;
  $returnValue = $row->[0];
  $session->log($Session::Info,"select_value returns more than 1 row.")
                  if $st->fetchrow_arrayref();
  return $returnValue;

}
=head2 select_values

   A convenience routine for selecting a specied number of multiple values
   with a sql select This puts the results of the select into a referenced 
   list of scalar references and returns the number of selected values.

=cut

sub select_values
{
  my $self = shift;
  my $sql = shift;
  my $dest = shift;

  my $startSize = scalar(@$dest);

  my $session = $self->{session};

  $session->log($Session::Verbose,"SQL: $sql");

  my $st = $self->{dbh}->prepare($sql);
  $st->execute();
  my $ctr = 0;
  while ( $row = $st->fetchrow_arrayref() ) {
    for(my $j=0;($j<=$#$row) && ($ctr<$startSize);$j++) {
       ${$dest->[$ctr]} = $row->[$j];
       $ctr++;
    }
    last if $ctr>=$startSize;
  }
  $st->finish();
  return $ctr;

}
=head2 select

   A convenience routine for selecting a multiple values with a sql select
   This puts the results of the select into a referenced array and returns
   the number of selected values.

=cut

sub select
{
  my $self = shift;
  my $sql = shift;
  my $dest = shift;

  my $startSize = scalar(@$dest);

  my $session = $self->{session};

  my $st = $self->{dbh}->prepare($sql);
  $st->execute();
  while ( $row = $st->fetchrow_arrayref() ) {
    push @$dest,@$row;
  }
  return scalar(@$dest)-$startSize;

}

sub query
{
  my $self = shift;
  my $sql = shift;
  my ($slice, $max_rows) = @_;

  my $session = $self->{session};
  my $st = $self->{dbh}->prepare($sql);
  $st->execute();
  my $rows = $st->fetchall_arrayref($slice, $max_rows);
  return ref($rows) eq 'ARRAY' && @$rows ? $rows : undef;
}

=head2 select_params

   A convenience routine for selecting a multiple values with a sql select
   This puts the results of the select into a referenced array and returns
   the number of selected values.

   This routine also acceps an array reference containing binding parameters
   and, optionally another array reference with binding types

=cut

sub select_params
{
  my $self = shift;
  my $sql = shift;
  my $dest = shift;
  my $params = shift;
  my $types = shift;

  my $startSize = scalar(@$dest);

  my $session = $self->{session};

  my $st = $self->{dbh}->prepare($sql);
  for (my $i=0; $i<@$params; $i++) {
    my $type;
    if ($types && $i<@$types && defined($types->[$i])) {
      $type = $types->[$i];
      $st->bind_param($i+1,$params->[$i], $type);
    } elsif ($types && $i>=@$types && defined($types->[$i%@$types])) {
      $type = $types->[$i%@$types]; 
      $st->bind_param($i+1,$params->[$i], $type);
    } else {
      $st->bind_param($i+1,$params->[$i]);
    }
  }
  $st->execute();
  while ( my $row = $st->fetchrow_arrayref() ) {
    my @row = @$row;
    push @$dest,\@row;
  }
  return scalar(@$dest)-$startSize;

}

=head2 lock/unlock

Lock a table. This may be driver specific so we've moved it here.
This returns a value that may be need by the unlocker.

=cut

sub lock
{
  my $self = shift;
  my $table = shift || return;
  
  my $return;

  if  ($self->{dbh}->{Driver}->{Name} eq 'Pg') {
    # for postgres, we unlock by committing a transaction.
    # if we're in a transaction externally. unlocking will occur
    # when we commit/rollback. Otherwise, we need to start a transaction
    if ($self->{dbh}{AutoCommit}) {
      $self->begin_work;
      $return = 'need to commit';
    } else {
      $return = '0';
    }
    $self->{dbh}->do("LOCK TABLE $table");
  #  } elsif (other_driver... {
  }
  return $return;

}

sub unlock
{
  my $self = shift;
  my $table = shift;
  my $flag = shift;

  if  ($self->{dbh}->{Driver}->{Name} eq 'Pg') {
    return unless $flag;
    $self->{dbh}->commit if $flag eq 'need to commit';
  }
  return;
}

=head2 session

   Returns the Session. Useful for logging

=cut

sub session
{
   return shift->{session};
}

=head1 time_value

  A static routine to reformat DBI time values into an implementation dependent string

=cut

sub time_value
{
   return shift;
}

sub quote {
  my $self = shift;
  my ($string) = @_;
  $string = $self->{dbh}->quote($string);

  # encode to utf-8
  # disabled for now, it's causing more problems than it's fixing
  # if ($has_encode) {
  #   $string = Encode::encode_utf8($string);
  # }

  # put quotes around arrays if necessary
  $string = "'$string'" 
    if ref $_[0] eq 'ARRAY' && $string !~ /^'.*'$/;
  return $string;
}

=head1 list_schemas

List all the schemas in a database

=cut

sub list_schemas {
  my $self = shift;
  my $schema = shift||'%';

  my $sth = $self->table_info('',$schema,'');
  my $href = $sth->fetchrow_hashref();
  my @return;
  while (defined $href) {
    push @return, $href->{TABLE_SCHEM};
    $href = $sth->fetchrow_hashref();
  }
  return @return;
}

=head1 list_tables

Return the list of tables in this database

=cut

sub list_tables {
  my $self = shift;
  my $schema = shift ||
   (($self->{dbh}->{Driver}->{Name} eq 'SQLite')?'main':'public');

  my $sth = $self->table_info('%',$schema,'%');
  my $href = $sth->fetchrow_hashref();
  my @return;
  while (defined $href) {
    push @return, $href->{TABLE_NAME};
    $href = $sth->fetchrow_hashref();
  }

  return @return;
}

=head1 list_cols

List the columns in a database table

=cut

sub list_cols {
  my $self = shift;
  my ($table, $schema, $col) = @_;
  return () if !$table;

  my $default_schema =
   (($self->{dbh}->{Driver}->{Name} eq 'SQLite')?'main':'public');

  my $sth = $self->column_info('%', $schema||$default_schema, $table, $col||'%');

  my %return;
  my $href = $sth->fetchrow_hashref();
  while (defined $href) {
    $return{$href->{ORDINAL_POSITION}} = $href->{COLUMN_NAME};
    $href = $sth->fetchrow_hashref();
  }
  return map {$return{$_}} sort {$a<=>$b} keys %return;
}

=head1 table_exists

Return the names of any tables matching the pattern that exist in the database.

=cut

sub table_exists {
  my $self = shift;
  my $table = shift || return
  my @return;

  my $default_schema =
   (($self->{dbh}->{Driver}->{Name} eq 'SQLite')?'main':'public');

  my $sth = $self->table_info('%',$default_schema,$table);
  my $href = $sth->fetchrow_hashref();
  while (defined $href) {
    push @return, $href->{TABLE_NAME};
    $href = $sth->fetchrow_hashref();
  }
  return @return;
}

=head2 Overloaded Methods

  we cannot overload DBI directly. So let's use autoload to access
  DBI methods

=cut

sub DESTROY {
}

sub AUTOLOAD {
  my $self = shift;
  my $db_call = $AUTOLOAD;

  return unless $self->{dbh};

  $db_call =~ s/.*:://;
  $db_call = 'errstr' if ('state' eq $db_call);

  $self->{session}->log($Session::SQL,"DBI call to $db_call".
    (@_?" with arg stack: ".join(" ",map {defined($_)?$_:'undef'} @_).".":"."));

  my $return = $self->{dbh}->$db_call(@_);

  # report non-zero error code. (but not for a call to 'state' itself
  $self->{session}->die("Error $DBI::errstr in processing command $db_call".
                         ((@_)?" with args @_":"")) if ($db_call ne 'errstr' && $self->{dbh}->errstr);
  return $return;
}

1;
