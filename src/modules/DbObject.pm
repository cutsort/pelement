=head1 Name

   DbObject.pm A superclass for modules that map to Db tables;

=head1 Usage

   This module is not used directly. The superclass deals with
   routine stuff such as reading/writing to the db.

   The assumption is that when this is called with a class
   'Class', there is a corresponding table 'class'.

   Furthermore, if there is a column 'id', then it is a unique
   integer identifier.

=cut

package DbObject;

use Exporter;
use Pelement;
use PCommon;
use Session;

use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(new initialize_self select select_if_exists db_exists insert
             update delete resolve_ref AUTOLOAD DESTROY);

=head1

  new, a generic 'turn a table into an object' constructor

=cut

sub new 
{
  my $class = shift;
  my $session = shift || die "Session argument required.";
  my $args = shift;

  my $self = initialize_self($class,$session,$args);

  return bless $self,$class;

}
    
=head1

  initialize_self creates a hash and prepares a set of keys for
  columns in the table.

  In addition to a key for each column, there are metatags for
  _table and _cols. The first is the name of the table, the second
  a reference to a list of column names.

=cut

sub initialize_self
{
  my $class = shift;

  # we require an argument to specify the session
  my $sessionHandle = shift ||
                     die "Session handle required for $class interface";

  # optional arguments for specifying fields.
  my $args = shift;

  # tablenames are case insensitive, right?
  my $tablename = $class;

  my $self = {};

  # internal stuff.
  $self->{_table}  = $tablename;
  $self->{_session} = $sessionHandle;
  $self->{_constraint} = '';

  my $cols = [];

  my $sql = $sessionHandle->db->prepare("Select * from $tablename limit 0");
  $sql->execute();

  $self->{_cols} = \@{$sql->{NAME}};
  # process any specified arguments
  map { $self->{$_} = PCommon::parseArgs($args,$_) } @{$self->{_cols}};

  # apply supplemental constraints.
  # nulls are specified by the contents of an array pointed to by the -null arg
  foreach my $is_null (@{PCommon::parseArgs($args,'null') || [] }) {
     $self->{_constraint} .= " $is_null is null and";
  }
  # not equals, greater than's and less than's are specified by hashes
  # of key/values
  my $ne_constraint = PCommon::parseArgs($args,'not_equal') || {};
  foreach my $not_equal (keys %$ne_constraint) {
     $self->{_constraint} .= " $not_equal != ".
             $sessionHandle->db->quote($ne_constraint->{$not_equal})." and";
  }
  my $gt_constraint = PCommon::parseArgs($args,'greater_than') || {};
  foreach my $greater_than (keys %$gt_constraint) {
     $self->{_constraint} .= " $greater_than > ".
             $sessionHandle->db->quote($gt_constraint->{$greater_than})." and";
  }
  my $lt_constraint = PCommon::parseArgs($args,'less_than') || {};
  foreach my $less_than (keys %$lt_constraint) {
     $self->{_constraint} .= " $not_equal < ".
             $sessionHandle->db->quote($lt_constraint->{$less_than})." and";
  }
  my $ge_constraint = PCommon::parseArgs($args,'greater_than_or_equal') || {};
  foreach my $greater_than (keys %$ge_constraint) {
     $self->{_constraint} .= " $greater_than >= ".
             $sessionHandle->db->quote($ge_constraint->{$greater_than})." and";
  }
  my $le_constraint = PCommon::parseArgs($args,'less_than_or_equal') || {};
  foreach my $less_than (keys %$le_constraint) {
     $self->{_constraint} .= " $not_equal <= ".
             $sessionHandle->db->quote($le_constraint->{$less_than})." and";
  }
  $self->{_constraint} =~ s/ and$//;

  $sql->finish();

  return $self;
}

=head1

   select Based on the filled fields, a database record is selected which
   matches the non-null fields. The returned record must be unique.

   TODO: specify additional qualifiers.

=cut

sub select
{
  my $self = shift;
  my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required db selection";

  # do we ignore warnings?
  my $ignoreWarnings = shift;

  return unless $self->{_table} && $self->{_cols};
  my $sql = "select ".join(",",@{$self->{_cols}})." from ".
                     ($self->{_table})." where";
  
  map { $sql .= " $_=".$sessionHandle->db->quote($self->{$_})." and"
                      if defined $self->{$_} } @{$self->{_cols}};
   
  $sql .= $self->{_constraint};
  # clean up
  $sql =~ s/ and$//;
  $sql =~ s/ where$//;

  $sessionHandle->log($Session::Verbose,"SQL: $sql.");

  my $st = $sessionHandle->db->prepare($sql);
  $st->execute;
  
  my $href = $st->fetchrow_hashref();
  ( ($ignoreWarnings || $sessionHandle->log($Session::Warn,
                                    "SQL $sql returned no object."))
                                           and return $self) unless $href;

  map { $self->{$_} = $href->{$_} } @{$self->{_cols}};
  
  $href = $st->fetchrow_hashref();
  $sessionHandle->log($Session::Warn,"SQL $sql returned multiple objects.")
                          if $href;
  $st->finish;

  return $self;
  
}

=head1 select_if_exists

  A variant which does not kvetch if an object does not exist

=cut

sub select_if_exists
{
  return shift->select(@_,1);
}


=head1 db_exists

  returns the count of the number of items that match the specified
  defined columns

=cut
  
sub db_exists
{
  my $self = shift;
  my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required db selection";

  return unless $self->{_table} && $self->{_cols};
  my $sql = "select count(*) from ".($self->{_table})." where";
  
  map { $sql .= " $_=".$sessionHandle->db->quote($self->{$_})." and" if defined $self->{$_} }
                   @{$self->{_cols}};
   
  # clean up
  $sql =~ s/ and$//;
  $sql =~ s/ where$//;

  $sessionHandle->log($Session::Verbose,"SQL: $sql.");
  return $sessionHandle->db->select_value($sql);
}
  
  

=head1 update

   update the current row with the revised info. The id designator
   must exists and be unique. Any other referential fields are frozen

=cut
sub update
{
   my $self = shift;
   my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required db selection";

   return unless $self->{_table} && $self->{_cols};
   my $sql = "update ".$self->{_table}." set ";
   foreach my $col (@{$self->{_cols}}) {
      $self->{$col} = $self->resolve_ref($self->{$col});
      next if $col eq "id";
      next unless defined $self->{$col};
      $sql .= "$col=".$self->{_session}->db->quote($self->{$col}).", ";
   }
   $sql =~ s/, $//;
   $sql .= " where id=".$self->{id};
   $self->{_session}->log($Session::Verbose,"Updating info for ".$self->{_table}.
                          " id=".$self->{id});
   $self->{_session}->db->do($sql);
}

=head1 delete

  Remove the item associated with the specified id.

=cut

sub delete
{
  my $self = shift;
  my  $sessionHandle = $self->{_session} || shift ||
                die "Session handle required for db deletion";
  return unless $self->{_table} && $self->{_cols};

  $sessionHandle->session->log($Session::Warn,"Cannot delete from ".$self->{_table}.
                            " without specifying an id.") and return unless $self->id;

  my $sql = "delete from ".$self->{_table}." where id= ".$self->id;

  $sessionHandle->log($Session::Verbose,"Deleting id=".$self->id." from ".$self->{_table}.".");
  $sessionHandle->db->do($sql);

}

=head1 insert

   Insert a new row in the db. The id identifier (if it exists) is returned.

=cut

sub insert
{
   my $self = shift;
   my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required db selection";

   return unless $self->{_table} && $self->{_cols};
   my $sql = "insert into ".$self->{_table}." (";
   my $sqlVal = ") values (";

   # we also prepare a query for the id we just got.
   my $qSql = "select max(id) from ".$self->{_table}." where ";

   foreach my $col (@{$self->{_cols}}) {
      $self->{$col} = $self->resolve_ref($self->{$col});
      next if $col eq "id";
      next unless defined $self->{$col};
      $sql .= $col.",";
      $sqlVal .= $self->{_session}->db->quote($self->{$col}).",";
      $qSql .= "$col=".$self->{_session}->db->quote($self->{$col})." and ";
   }
   $sql =~ s/,$//;
   $sqlVal =~ s/,$/)/;
   $sql .= $sqlVal;
   $qSql =~ s/ and $//;
   $self->{_session}->log($Session::Verbose,"Inserting info to ".$self->{_table});
   $self->{_session}->db->do($sql);

   return unless exists $self->{id};

   $self->{id} = $self->{_session}->db->select_value($qSql);

   return $self->{id};
}
   
=head1 resolve_ref

  internal convenience routine for finding the eventual value of
  a scalar reference.

=cut

sub resolve_ref
{
   my $self = shift;
   my $thingy = shift;
   my  %beenThereDoneThat = ();
   while ( ref($thingy) eq "SCALAR" ) {
      $self->{_session}->log($Session::Verbose,"Resolving scalar referance.");
      $self->{_session}->error("Circular Reference","Scalar reference loop.")
                   if ( $beenThereDoneThat{$thingy});
      $beenThereDoneThat{$thingy} = 1;
      $thingy = ${$thingy};
   }
   return $thingy;
}

sub AUTOLOAD
{
  my $self = shift;
  croak "$self is not an object." unless ref($self);
  my $name = $AUTOLOAD;

  $name =~ s/.*://;
  if (! exists( $self->{$name} ) ) {
     $self->{_session}->error("No method","$name is not a method for ".ref($self).".");
  }
  $self->{$name} = shift @_ if ( @_ );
  return $self->{$name};
}

sub DESTROY {}

1;

