=head1 Name

   DbObjectSet.pm A superclass for modules that contain collections
   of things that map to Db tables;

=head1 Usage

   This module is not used directly. The superclass deals with
   routine stuff such as reading/writing to the db.

   The assumption is that when this is called with a class
   'Class', there is a corresponding table 'class'. After we
   create a general *Set object, we fill the restrictive fields
   and query the db for those objects that satisfy the contraints.

=cut

package DbObjectSet;

use Exporter;
use Pelement;
use PCommon;
use Session;

use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(new initialize_self select as_list as_list_ref AUTOLOAD DESTROY);

=head1

  new  a simple contructor

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

  # optional preset args.
  my $args = shift || {};

  $sessionHandle->log($Session::Error,"$class is not an ObjectSet class.")
                                                         unless $class =~/Set$/;
  (my $tablename = $class) =~ s/Set$//;

  my $self = {};

  $self->{_table}  = $tablename;
  $self->{_session} = $sessionHandle;
  $self->{_constraint} = '';

  my $sql = $sessionHandle->db->prepare("Select * from $tablename limit 0");
  $sql->execute();
  $self->{_cols} = \@{$sql->{NAME}};
  $self->{_objects} = [];

  # process any specified arguments
  map { $self->{$_} = PCommon::parseArgs($args,$_) } @{$self->{_cols}};

  # apply supplemental constraints.
  # nulls are specified by the contents of an array pointed to by the -null arg
  foreach my $is_null (@{PCommon::parseArgs($args,'null') || [] }) {
     $self->{_constraint} .= " $is_null is null and";
  }
  # not equals, greater than's and less than's are specified by hashes of key/values
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
     $self->{_constraint} .= " $less_than < ".
             $sessionHandle->db->quote($lt_constraint->{$less_than})." and";
  }
  my $ge_constraint = PCommon::parseArgs($args,'greater_than_or_equal') || {};
  foreach my $greater_than (keys %$ge_constraint) {
     $self->{_constraint} .= " $greater_than >= ".
             $sessionHandle->db->quote($ge_constraint->{$greater_than})." and";
  }
  my $le_constraint = PCommon::parseArgs($args,'less_than_or_equal') || {};
  foreach my $less_than (keys %$le_constraint) {
     $self->{_constraint} .= " $less_than <= ".
             $sessionHandle->db->quote($le_constraint->{$less_than})." and";
  }
  my $like_constraint = PCommon::parseArgs($args,'like') || {};
  foreach my $like (keys %$like_constraint) {
     $self->{_constraint} .= " $like like ".
             $sessionHandle->db->quote($like_constraint->{$like})." and";
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

  return unless $self->{_table} && $self->{_cols};

  my $class = $self->{_table};
  require $class.'.pm';

  my $sql = "select ".join(",",@{$self->{_cols}})." from ".($self->{_table})." where";
  
  map { $sql .= " $_=".$sessionHandle->db->quote($self->{$_})." and" if defined($self->{$_})}
                   @{$self->{_cols}};
   
  $sql .= $self->{_constraint};
  # clean up
  $sql =~ s/ and$//;
  $sql =~ s/ where$//;

  $sessionHandle->log($Session::Verbose,"SQL: $sql.");

  my $st = $sessionHandle->db->prepare($sql);
  $st->execute;
  
  while ( my $href = $st->fetchrow_hashref() ) {
    my $new_self = $class->new($sessionHandle);
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

sub DESTROY {}

=head1 AUTOLOAD

  default setter/getter for db columns

=cut

sub AUTOLOAD
{
  my $self = shift;
  croak "$self is not an object." unless ref($self);
  my $name = $AUTOLOAD;

  $name =~ s/.*://;
  if (! exists( $self->{$name} ) ) {
     $self->{_session}->error("$name is not a method for ".ref($self).".");
  }
  $self->{$name} = shift @_ if ( @_ );
  return $self->{$name};
}


1;

