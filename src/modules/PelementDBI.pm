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

=head2 Overloaded Methods

  we cannot overload DBI directly. So let's use autoload to access
  DBI methods

=cut

sub AUTOLOAD {
  my $self = shift;
  my $db_call = $AUTOLOAD;

  $db_call =~ s/.*:://;

  return $self->{dbh}->$db_call(@_);
}

1;
