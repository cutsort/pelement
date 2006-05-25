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
@EXPORT = qw(new initialize_self select select_if_exists db_exists db_count insert
             unique_identifier get_next_id set_id update delete ref_of
             resolve_ref session AUTOLOAD DESTROY);

=head1

  new, a generic 'turn a table record into an object' constructor. This is not
  meant to be instanced directly, but rather through an inherited class.

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

  # try to read a cached (a.k.a.stashed) record of
  # column names for this table.
  unless ( exists $self->{_cols} &&
           scalar @{$self->{_cols} = [ @{$self->{_session}->{col_hash}->{$tablename}} ]} ) {
     my $sql = $sessionHandle->db->prepare(qq(
                    Select * from $tablename where false;));
     # why do I need the execute? Other drivers seem to
     # require this. But it don't hurt.
     $sql->execute();
     $self->{_session}->{col_hash}->{$tablename} = [@{$sql->{NAME}}];
     $self->{_cols} = \@{$sql->{NAME}};
     $sql->finish();
  }

  # process any specified arguments
  map { $self->{$_} = parseArgs($args,$_) } @{$self->{_cols}};

  # apply supplemental constraints.
  # nulls are specified by the contents of an array pointed to by the -null arg
  foreach my $is_null (@{parseArgs($args,'null') || [] }) {
     $self->{_constraint} .= " $is_null is null and";
  }
  # not nulls are specified by the contents of an array pointed to by the
  # -notnull arg
  foreach my $isnt_null (@{parseArgs($args,'notnull') || [] }) {
     $self->{_constraint} .= " $isnt_null is not null and";
  }
  # not equals, greater than's and less than's are specified by hashes
  # of key/values
  my $ne_constraint = parseArgs($args,'not_equal') || {};
  foreach my $not_equal (keys %$ne_constraint) {
     $self->{_constraint} .= " $not_equal != ".
             $sessionHandle->db->quote($ne_constraint->{$not_equal})." and";
  }
  my $gt_constraint = parseArgs($args,'greater_than') || {};
  foreach my $greater_than (keys %$gt_constraint) {
     $self->{_constraint} .= " $greater_than > ".
             $sessionHandle->db->quote($gt_constraint->{$greater_than})." and";
  }
  my $lt_constraint = parseArgs($args,'less_than') || {};
  foreach my $less_than (keys %$lt_constraint) {
     $self->{_constraint} .= " $less_than < ".
             $sessionHandle->db->quote($lt_constraint->{$less_than})." and";
  }
  my $ge_constraint = parseArgs($args,'greater_than_or_equal') || {};
  foreach my $greater_than_or_equal (keys %$ge_constraint) {
     $self->{_constraint} .= " $greater_than_or_equal >= ".
             $sessionHandle->db->quote($ge_constraint->{$greater_than_or_equal})." and";
  }
  my $le_constraint = parseArgs($args,'less_than_or_equal') || {};
  foreach my $less_than_or_equal (keys %$le_constraint) {
     $self->{_constraint} .= " $less_than_or_equal <= ".
             $sessionHandle->db->quote($le_constraint->{$less_than_or_equal})." and";
  }
  my $like_constraint = parseArgs($args,'like') || {};
  foreach my $like (keys %$like_constraint) {
     $self->{_constraint} .= " $like like ".
             $sessionHandle->db->quote($like_constraint->{$like})." and";
  }
  $self->{_constraint} =~ s/ and$//;

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

  $sessionHandle->log($Session::SQL,"SQL: $sql.");

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

  returns the existence of items that match the specified
  defined columns

=cut

sub db_exists
{
  my $self = shift;
  my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required db selection";

  return unless $self->{_table} && $self->{_cols};
  my $sql = "select * from ".($self->{_table})." where";

  map { $sql .= " $_=".$sessionHandle->db->quote($self->{$_})." and" if defined $self->{$_} }
                   @{$self->{_cols}};

  # clean up
  $sql =~ s/ and$//;
  $sql =~ s/ where$//;

  $sql = 'select exists( '.$sql.' )';

  $sessionHandle->log($Session::SQL,"SQL: $sql.");
  return $sessionHandle->db->select_value($sql);
}

=head1 db_count

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

  $sessionHandle->log($Session::SQL,"SQL: $sql.");
  return $sessionHandle->db->select_value($sql);
}

=head1

   unique_identifer selects some sort of unique id for the record. This will
   be DB dependent.

=cut

sub unique_identifier
{
   my $self = shift;
   my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required db selection";

  # do we ignore warnings?
  my $ignoreWarnings = shift;

  return unless $self->{_table} && $self->{_cols};

  my $sql;
  if ($sessionHandle->db->{dbh}->{Driver}->{Name} eq 'Pg') {
      $sql = "select oid from ".($self->{_table})." where";
  } else {
      die "do not know how to deal with this dbi driver.";
  }

  map { $sql .= " $_=".$sessionHandle->db->quote($self->{$_})." and"
                      if defined $self->{$_} } @{$self->{_cols}};


  $sql .= $self->{_constraint};
  # clean up
  $sql =~ s/ and$//;
  $sql =~ s/ where$//;

  $sessionHandle->log($Session::SQL,"SQL: $sql.");

  my $st = $sessionHandle->db->prepare($sql);
  $st->execute;

  my @oidA = $st->fetchrow_array();
  ( ($ignoreWarnings || $sessionHandle->log($Session::Warn,
                                    "SQL $sql returned no object id."))
                                           and return $self) unless @oidA;

  $self->{oid} = $oidA[0];

  $oidA = $st->fetchrow_array();
  $sessionHandle->log($Session::Warn,"SQL $sql returned multiple objects.")
                          if @oidA;
  $st->finish;

  return $self;

}

=head1 update

   update the current row with the revised info.
   If an id designator exists, it must be unique.
   In that case it will be used to key the update.
   Otherwise, optional arguments are specified to key the
   update.

   Any other referential fields are frozen

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
   if (@_) {
      $sql .= " where ";
      while(@_) {
         my $arg = shift;
         $sql .= "$arg=".$self->{_session}->db->quote($self->{$arg})." and ";
      }
      $sql =~ s/ and $//;
   } elsif ($self->{oid}) {
      $sql .= " where oid=".$self->{oid};
   } elsif ($self->{id}) {
      $sql .= " where id=".$self->{id};
   } else {
      $self->{_session}->warn("Non-effective update on ".$self->{_table});
      return;
   }

   $self->{_session}->verbose("Updating info for ".$self->{_table}.
           ($self->{id}?" id=".$self->{id}:" and specified keys."));
   $self->{_session}->db->do($sql);
}

=head1 delete

  Remove the item associated with the specified id.

=cut

sub delete
{
  my $self = shift;
  my $sessionHandle = $self->{_session} || shift ||
                die "Session handle required for db deletion";
  return unless $self->{_table} && $self->{_cols};

  my $sql = "delete from ".$self->{_table};

  # see if we have a set of keys to trigger the delete
  if (@_) {
      $sql .= " where ";
      while(@_) {
         my $arg = shift;
         $sql .= "$arg=".$sessionHandle->db->quote($self->{$arg})." and ";
      }
      $sql =~ s/ and $//;
   } elsif ($self->{oid}) {
      $sql .= " where oid=".$self->{oid};
   } elsif ($self->{id}) {
      $sql .= " where id=".$self->{id};
   } else {
      $sessionHandle->warn("Cannot delete from ".$self->{_table}.
                            " without specifying a key.");
      return;
   }


  if (exists($self->{id})) {
     $sessionHandle->verbose("Deleting id=".$self->id." from ".$self->{_table}.".");
  } else {
     $sessionHandle->verbose("Deleting from ".$self->{_table}.".");
  }
  $sessionHandle->db->do($sql);

  return $self;

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
      #next if $col eq "id";
      next unless defined $self->{$col};
      $sql .= $col.",";
      $sqlVal .= $self->{_session}->db->quote($self->{$col}).",";
      $qSql .= "$col=".$self->{_session}->db->quote($self->{$col})." and ";
   }
   $sql =~ s/,$//;
   $sqlVal =~ s/,$/)/;
   $sql .= $sqlVal;
   $qSql =~ s/ and $//;
   $self->{_session}->verbose("Inserting info to ".$self->{_table});

   my $statement = $self->{_session}->db->prepare($sql);
   $statement->execute;

   if ($sessionHandle->db->{dbh}->{Driver}->{Name} eq 'Pg') {
      # we can determine the record in a intelligent manner in a DB dependent way
      my $oid = $statement->{pg_oid_status};
      # now do a select to find any default fields filled in.
      # this isn't right now. it's only getting an 'id' field; but 1) other
      # fields may have defaults and 2) trimming may modify some and 3) triggers
      # or rules could modify others
      $self->{id} = $self->{_session}->db->select_value("select id from ".
                      $self->{_table}." where oid=$oid") if exists $self->{id};
   } else {
      return unless exists $self->{id};
      $self->{id} = $self->{_session}->db->select_value($qSql);
   }

   return unless exists $self->{id};
   return $self->{id};
}

=head1 get_next_id

   This is bound to be db specific. We use this to get and 'reserve' the
   next serial counter for a table. For db's that implement sequences this
   will look up and bump up the sequence associated with the id. Normally
   this is expected to be the 'id' column, but can another counter name
   can be supplied

=cut

sub get_next_id
{
   my $self = shift;
   my $sessionHandle = $self->session ||
                die "Session handle when getting id";

   return unless $self->{_table} && $self->{_cols};

   my $col = shift || 'id';

   # postgres
   if ($sessionHandle->db->{dbh}->{Driver}->{Name} eq 'Pg') {
      my $iGot =  $sessionHandle->db->select_value("select nextval('".$self->{_table}."_".$col."_seq')");
      return $iGot;
   } else {
      $sessionHandle->error("Unimplemented DB driver for get_next_id.");
   }
}

=head1 set_id

   If we have manipulated a sequence variable manually, we may have to
   reset the corresponding sequence to keep things in sync. This will return
   the set value

=cut

sub set_id
{
   my $self = shift;
   my $sessionHandle = $self->{_session} ||
                die "Session handle when setting id";

   my $val =  shift;
   return unless $self->{_table} && $self->{_cols};

   my $col = shift || 'id';

   # postgres
   if ($sessionHandle->db->{dbh}->{Driver}->{Name} eq 'Pg') {
      my $iGot =  $sessionHandle->db->select_value("select setval('".$self->{_table}."_".$col."_seq',$val)");
      return $iGot;
   } else {
      $sessionHandle->error("Unimplemented DB driver for set_id.");
   }
}


=head1 session

  returns the session object

=cut
sub session
{
  return shift->{_session};
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
      $self->{_session}->verbose("Resolving scalar referance.");
      $self->{_session}->error("Scalar reference loop.")
                   if ( $beenThereDoneThat{$thingy});
      $beenThereDoneThat{$thingy} = 1;
      $thingy = ${$thingy};
   }
   return $thingy;
}

=head1 ref_of

  returns a reference to the field. promiscous: anyone can mess with it.

=cut
sub ref_of
{
   my $self = shift;
   my $name = shift;
   if (! exists( $self->{$name} ) ) {
     $self->{_session}->error("$name is not a column for ".ref($self).".");
   }
   return \$self->{$name};
}

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

sub DESTROY {}

1;

