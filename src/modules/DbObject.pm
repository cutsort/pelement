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

use Session;
use Carp;
use strict;
use warnings;

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
  return $self;
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
  my $session = shift ||
    die "Session handle required for $class interface";

  # optional arguments for specifying fields.
  my $args = shift || {};
  my $module = shift || $class;
  my $self = bless {}, $class;

  $self->{_session} = $session;

  $self->{_schema} = $class =~ /^(.*)::/ ? $1 : undef;
  $self->{_module}  = $module;

  ($self->{_tablename} = $self->{_module}) =~ s/^.*://;
  $self->{_tablename} = 
    $session->{tables_hash}{$self->{_module}} 
    || $self->{_tablename};
  $self->{_table} = 
    ($self->{_schema} ? ($self->_qi($self->{_schema}).'.') : '')
    .$self->{_tablename};

  # try to read a cached (a.k.a.stashed) record of
  # column names for this table.
  if (!(exists($self->{_session}{cols}{$self->{_module}}) &&
    scalar(@{$self->{_cols} 
      = [ @{$self->{_session}{cols}{$self->{_module}}} ]}) )) 
  {
     # do a table name lookup. This is done because table names are quoted, 
     # and must be entered case-sensitively. This way we can allow case-insensitive
     # lookups.
     my %tables = map {$_=>$_} $self->{_session}->db->list_tables(
       $self->{_schema}
     );
     my %lctables = map {lc($_)=>$_} keys %tables;

     # perform the lookup and set _tablename
     $self->{_tablename} = 
       $tables{$self->{_tablename}} 
       || $lctables{lc($self->{_tablename})} 
       || $tables{$self->_qi($self->{_tablename})} 
       || $lctables{$self->_qi(lc($self->{_tablename}))} 
       || $self->{_session}->die("$self->{_tablename} is not a known table"
         .($self->{_schema} ? " for schema $self->{_schema}":'').".");

     # _table is _tablename with the schema prepended
     $self->{_table} = 
       ($self->{_schema} ? ($self->_qi($self->{_schema}).'.') : '')
       .$self->{_tablename};

     # Do a lookup to get the list of columns.
     # For some reason, if the tablename you got from list_tables is quoted,
     # and you try to pass it in to list_cols verbatim, it doesn't return anything.
     # So, at least for Postgres, remove the quotes first.
     my $tablename = $self->{_tablename};
     if ($session->db->{dbh}->{Driver}->{Name} eq 'Pg') {
       $tablename = $1 if $self->{_tablename} =~ /^"(.*)"$/;
     }
     $self->{_cols} = [
       $self->{_session}->db->list_cols($tablename, $self->{_schema})
     ];

     # cache the table name and column names for fast lookup next time
     $self->{_session}{tables_hash}{$self->{_module}} = $self->{_tablename};
     $self->{_session}{cols}{$self->{_module}} = $self->{_cols};
     $self->{_session}{cols_hash}{$self->{_module}} = {map {$_=>$_} @{$self->{_cols}}};
     $self->{_session}{lccols_hash}{$self->{_module}} = {map {lc($_)=>$_} @{$self->{_cols}}};
  }

  $self->{_args} = $args;

  # process any specified arguments
  for (keys %$args) {
    my $key = $self->_convert_col($_);
    $self->$key(delete $args->{$_}) if $self->has_col($key);
  }

  # evaluate the memoized stuff to clear those keys out of $args
  $self->_constraints;
  $self->_clauses;
  # what's left in $args now can only be a typo
  $session->die("Invalid arguments passed to ".ref($self).': '.join(',',keys %{$self->{_args}}))
    if keys %{$self->{_args}||{}};

  return $self;
}

=head1

   select Based on the filled fields, a database record is selected which
   matches the non-null fields. The returned record must be unique.

=cut

sub select
{
  my $self = shift;
  my $session = $self->{_session} || 
    die "Session handle required db selection";

  # do we ignore warnings?
  my $ignoreWarnings = shift;
  my %errorOptions = ( 
    -onnull => 'warn',
    -onmany => 'warn' 
  ); 

  # if $ignoreWarnings is a reference, it may have detailed
  # behavior of what to do
  if (ref($ignoreWarnings) eq 'HASH') {
    $errorOptions{$_} = $ignoreWarnings->{$_} for keys %$ignoreWarnings;
  }
  elsif ($ignoreWarnings) {
    $errorOptions{-onnull} = 'ignore';
  }
  return unless $self->{_table} && $self->{_cols};

  # apply rewrite rules
  $self->rewrite;

  my ($st, $sql) = $self->perform_select;
  my $href = $st->fetchrow_arrayref();
  if (!$href) {
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

  my $ctr = 0;
  $self->{$_} = $href->[$ctr++] for @{$self->{_cols}};

  $href = $st->fetchrow_arrayref();
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

=head1 rewrite

The default rewrite rule is nothing. This needs to be overridden as needed.

=cut

sub rewrite
{
  my $self = shift;
  return $self;
}

sub get_sql {
  my $self = shift;
  my $sql = "select ".$self->_cols_list." from ".$self->_table." where";
  $sql .= $self->where_clause;
  $sql = $self->_cleanup($sql);
  $sql .= $self->_clauses;
  $sql = $self->_cleanup($sql);
  return $sql;
}

sub perform_select {
  my ($self) = @_;
  my $session = $self->{_session} ||
    die "Session handle required db selection";

  my $sql = $self->get_sql;
  $session->log($Session::SQL,"SQL: $sql.");

  my $st = $session->db->prepare($sql);
  $st->execute;

  $session->die("$DBI::errstr in processing SQL: $sql")
    if $session->db->state;

  return ($st, $sql);
}

sub where_clause {
  my $self = shift;
  my $sql = '';
  $sql .= $self->_mappings;
  $sql .= $self->_constraints;
  $sql = $self->_cleanup($sql);
  return $sql;
}

=head1 select_if_exists

  A variant which does not kvetch if an object does not exist

=cut

sub select_if_exists {
  return shift->select({-onnull=>'ignore'});
}

=head1 select_or_die

  A bitchy version which dies with an error message if a record does not exist

=cut
sub select_or_die {
  return shift->select({-onnull=>'die'});
}

=head1 db_exists

  returns the count of the number of items that match the specified
  defined columns

=cut

sub db_exists
{
  my $self = shift;
  my $session = $self->{_session} || 
    die "Session handle required db selection";
  return unless $self->{_table} && $self->{_cols};

  $self->rewrite();

  my $sql = "select count(*) from ".$self->_table." where"; 
  $sql .= $self->_mappings;
  $sql .= $self->_constraints;
  $sql = $self->_cleanup($sql);

  $session->log($Session::SQL,"SQL: $sql.");
  return $session->db->select_value($sql);
}

=head1

   unique_identifer selects some sort of unique id for the record. This will
   be DB dependent.

=cut

sub unique_identifier
{
  my $self = shift;
  my $session = $self->{_session} || 
    die "Session handle required db selection";
  return unless $self->{_table} && $self->{_cols};

  die "do not know how to deal with this dbi driver."
    if $session->db->{dbh}->{Driver}->{Name} ne 'Pg';

  # do we ignore warnings?
  my $ignoreWarnings = shift;

  my $sql = "select oid from ".$self->_table." where";
  $sql .= $self->_mappings;
  $sql .= $self->_constraints;
  $sql = $self->_cleanup($sql);
  $session->log($Session::SQL,"SQL: $sql.");

  my $st = $session->db->prepare($sql);
  $st->execute;
  $session->die("$DBI::errstr in processing SQL: $sql")
    if $session->db->state;

  my @oidA = $st->fetchrow_array();
  if (!@oidA  && !$ignoreWarnings) {
    $session->log($Session::Warn, "SQL $sql returned no object id.");
    return $self;
  }
  $self->{oid} = $oidA[0];

  @oidA = $st->fetchrow_array();
  $session->log($Session::Warn,"SQL $sql returned multiple objects.") if @oidA;
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
   my $session = $self->{_session} 
     || die "Session handle required db selection";
   return unless $self->{_table} && $self->{_cols};

   my $sql = "update ".$self->{_table}." set ";
   $sql .= $self->_cols_values;

   if (@_) {
      $sql .= " where ";
      $sql .= $self->_mappings(@_);
      $sql = $self->_cleanup($sql);
   } 
   elsif ($self->{id}) {
      $sql .= " where id=".$self->{id};
   } 
   elsif ($self->{oid}) {
      $sql .= " where oid=".$self->{oid};
   } 
   else {
      $self->{_session}->warn("Non-effective update on ".$self->{_table});
      return;
   }
   $sql .= " returning *" if $session->db->{dbh}{Driver}{Name} eq 'Pg';

   $self->{_session}->log($Session::Verbose,"Updating info for ".$self->{_table}
     .($self->{id} ? " id=".$self->{id} : " and specified keys."));

   my $statement = $self->{_session}->db->prepare($sql);
   my $ret = $statement->execute;
   $session->die("$DBI::errstr in processing SQL: $sql") if $session->db->state;

   if ($session->db->{dbh}{Driver}{Name} eq 'Pg') {
      my $href = $statement->fetchrow_arrayref();
      if ($href) {
        my $ctr = 0;
        $self->{$_} = $href->[$ctr++] for @{$self->{_cols}};
      }
   }
   return $ret;
}

=head1 insert_or_update

Perform either an insert or an update depending on whether the record already exists

=cut

sub insert_or_update
{
  my $self = shift;
  my $session = $self->{_session} || die "Session handle required";

  my $module = $self->{_module};
  if ($session->table($module, { map {$_=>$self->$_} @_ })->db_exists) {
    return $self->update(@_);
  }
  else {
    return $self->insert(@_);
  }
}

=head1 insert_or_ignore

Perform an insert only if the record does not already exist

=cut

sub insert_or_ignore {
  my $self = shift;
  my $session = $self->{_session} || die "Session handle required";

  my $module = $self->{_module};
  if ($session->table($module, { map {$_=>$self->$_} @_ })->db_exists) {
    return;
  }
  else {
    return $self->insert(@_);
  }
}

=head1 delete

  Remove the item associated with the specified id.

=cut

sub delete
{
  my $self = shift;
  my $session = $self->{_session} 
    || die "Session handle required for db deletion";
  return unless $self->{_table} && $self->{_cols};

  my $sql = "delete from ".$self->_table;

  # see if we have a set of keys to trigger the delete
  if (@_) {
    $sql .= " where ";
    $sql .= $self->_mappings(@_);
    $sql = $self->_cleanup($sql);
  } 
  elsif ($self->{id}) {
    $sql .= " where id=".$self->{id};
  } 
  else {
    $session->warn("Cannot delete from ".$self->{_table}.
      " without specifying a key.");
    return;
  }
  if (exists($self->{id})) {
    $session->log($Session::Verbose,"Deleting id=".$self->id
      ." from ".$self->{_table}.".");
  } 
  else {
    $session->log($Session::Verbose,"Deleting from ".$self->{_table}.".");
  }
  $session->db->do($sql);
}

=head1 insert

   Insert a new row in the db. The id identifier (if it exists) is returned.

=cut

sub insert
{
   my $self = shift;
   my $session = $self->{_session} 
     || die "Session handle required db selection";
   return unless $self->{_table} && $self->{_cols};

   $self->{_session}->log(
     $Session::Verbose,"Inserting info to ".$self->{_table});

   my ($cols_list, $vals_list) = $self->_cols_values_lists;
   my $sql = 'insert into '.$self->_table.' '
     .($cols_list eq ''? '':"($cols_list) ")
     .($vals_list eq ''? 'default values':"values ($vals_list)");
   $sql .= " returning *" if $session->db->{dbh}{Driver}{Name} eq 'Pg';

   my $statement = $self->{_session}->db->prepare($sql);
   $statement->execute;
   $session->die("$DBI::errstr in processing SQL: $sql") if $session->db->state;

   if ($session->db->{dbh}{Driver}{Name} eq 'Pg') {
      my $href = $statement->fetchrow_arrayref();
      if ($href) {
        my $ctr = 0;
        $self->{$_} = $href->[$ctr++] for @{$self->{_cols}};
      }
   }
   return exists $self->{id}? $self->{id} : ();
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
   my $session = $self->session ||
                die "Session handle when getting id";

   return unless $self->{_table} && $self->{_cols};

   my $col = shift || 'id';
   $col = $self->_convert_col($col);

   # postgres
   if ($session->db->{dbh}{Driver}{Name} eq 'Pg') {
     my $nextval = $self->_nextval($col);
      my $iGot =  $session->db->select_value(
        "select nextval('$nextval')");
      return $iGot;
   } else {
      $session->error("Unimplemented DB driver for get_next_id.");
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
   my $session = $self->{_session} 
     || die "Session handle when setting id";

   my $val =  shift;
   return unless $self->{_table} && $self->{_cols};

   my $col = shift || 'id';
   $col = $self->_convert_col($col);

   # postgres
   if ($session->db->{dbh}{Driver}{Name} eq 'Pg') {
     my $nextval = $self->_nextval($col);
     my $iGot =  $session->db->select_value(
       "select setval('$nextval',$val)");
     return $iGot;
   } 
   else {
      $session->error("Unimplemented DB driver for set_id.");
   }
}

=head1 _extract_args

Remove and return a value from the $args hash.

=cut

sub _extract_args {
  my ($args, $key) = @_;
  return exists($args->{"-$key"})? delete $args->{"-$key"}: delete $args->{$key};
}

=head1 clauses

Process extra SQL clauses such as order by, limit, and offset

=cut

sub _clauses {
  my $self = shift;
  my $args = shift || $self->{_args};
  return $self->{_clauses} if exists $self->{_clauses};
  my $clauses = '';

  # process order by clauses
  my $order_by = _extract_args($args, 'order_by');
  if ($order_by) {
    $clauses .= ' order by ';
    for (@$order_by) { 
      /^([-+]?)(.*)$/;
      $clauses .= $2.($1 eq '-' ? ' desc' : '').',';
    }
    $clauses =~ s/,$//;
  }

  # process limit and offset clauses
  my $limit = _extract_args($args,'limit') || '';
  $clauses .= " limit $limit " if $limit;
  my $offset = _extract_args($args,'offset') || '';
  $clauses .= " offset $offset " if $limit && $offset;

  $self->{_clauses} = $clauses;
  return $clauses;
}

=head1

  process _constraints

=cut

sub _constraints
{
  my $self = shift;
  my $args = shift || $self->{_args};
  return $self->{_constraints} if exists $self->{_constraints};
  my $session = $self->{_session};
  my $constraint = '';

  # apply supplemental constraints.
  # nulls are specified by the contents of an array pointed to by the -null arg
  for my $is_null (@{_extract_args($args,'null') || [] }) {
     $constraint .= " ".$self->_convert_col($is_null)." is null and";
  }
  # not nulls are specified by the contents of an array pointed to by the
  # -notnull arg
  for my $isnt_null (@{_extract_args($args,'notnull') || [] }) {
     $constraint .= " ".$self->_convert_col($isnt_null)." is not null and";
  }

  # not equals, greater than's and less than's are specified by hashes of key/values
  my $eq_constraint = _extract_args($args,'equal_to') || {};
  for my $equal (keys %$eq_constraint) {
     $constraint .= " ".$self->_convert_col($equal)." = ".
             $session->db->quote($eq_constraint->{$equal})." and";
  }
  my $ne_constraint = _extract_args($args,'not_equal') || {};
  for my $not_equal (keys %$ne_constraint) {
     $constraint .= " ".$self->_convert_col($not_equal)." != ".
             $session->db->quote($ne_constraint->{$not_equal})." and";
  }
  my $gt_constraint = _extract_args($args,'greater_than') || {};
  for my $greater_than (keys %$gt_constraint) {
     $constraint .= " ".$self->_convert_col($greater_than)." > ".
             $session->db->quote($gt_constraint->{$greater_than})." and";
  }
  my $lt_constraint = _extract_args($args,'less_than') || {};
  for my $less_than (keys %$lt_constraint) {
     $constraint .= " ".$self->_convert_col($less_than)." < ".
             $session->db->quote($lt_constraint->{$less_than})." and";
  }
  my $ge_constraint = _extract_args($args,'greater_than_or_equal') || {};
  for my $greater_than (keys %$ge_constraint) {
     $constraint .= " ".$self->_convert_col($greater_than)." >= ".
             $session->db->quote($ge_constraint->{$greater_than})." and";
  }
  my $le_constraint = _extract_args($args,'less_than_or_equal') || {};
  for my $less_than (keys %$le_constraint) {
     $constraint .= " ".$self->_convert_col($less_than)." <= ".
             $session->db->quote($le_constraint->{$less_than})." and";
  }
  my $like_constraint = _extract_args($args,'like') || {};
  for my $like (keys %$like_constraint) {
     $constraint .= " ".$self->_convert_col($like)." like ".
             $session->db->quote($like_constraint->{$like})." and";
  }
  my $ilike_constraint = _extract_args($args,'ilike') || {};
  for my $ilike (keys %$ilike_constraint) {
     $constraint .= " ".$self->_convert_col($ilike)." ilike ".
             $session->db->quote($ilike_constraint->{$ilike})." and";
  }
  my $in_constraint = _extract_args($args,'in') || {};
  for my $in (keys %$in_constraint) {
     my $in_list = ref($in_constraint->{$in}) eq 'ARRAY'
       ? $in_constraint->{$in} : [$in_constraint->{$in}];
     $constraint .= " ".$self->_convert_col($in)." in ("
       .((@$in_list>0)
         ? (join(',',map {$session->db->quote($_)} @$in_list))
         : 'NULL')
       .") and";
  }
  my $not_in_constraint = _extract_args($args,'not_in') || {};
  for my $not_in (keys %$not_in_constraint) {
     my $not_in_list = ref($not_in_constraint->{$not_in}) eq 'ARRAY'
       ? $not_in_constraint->{$not_in} : [$not_in_constraint->{$not_in}];
     $constraint .= " ".$self->_convert_col($not_in)." not in ("
       .((@$not_in_list>0)
         ? (join(',',map {$session->db->quote($_)} @$not_in_list))
         : 'NULL')
       .") and";
  }
  my $bin_constraint = _extract_args($args, 'rtree_bin') || {};
  for my $bin (keys %$bin_constraint) {
    $constraint .= " ".RTree::bin_sql(
      @{$bin_constraint->{$bin}}[0..1], 
      $self->_convert_col($bin)
    )." and";
  }
  my $overlaps_constraint = _extract_args($args,'overlaps') || {};
  for my $overlaps (keys %$overlaps_constraint) {
    my $o = $overlaps_constraint->{$overlaps};
    if (ref($o) eq 'ARRAY'
      && defined($o->[0][0]) && $o->[0][0] =~ /^\d+$/
      && defined($o->[0][1]) && $o->[0][1] =~ /^\d+$/
      && defined($o->[1][0]) && $o->[1][0] =~ /^\d+$/
      && defined($o->[1][1]) && $o->[1][1] =~ /^\d+$/)
    {
      my $ostr = "($o->[0][0],$o->[0][1]),($o->[1][0],$o->[1][1])";
      $constraint .= " ".$self->_convert_col($overlaps)
        ." && ".$session->db->quote($ostr)." and";
    }
  }

  # arbitrary SQL constraint (use sparingly)
  my $sql_constraint = _extract_args($args, 'sql_code') || [];
  $sql_constraint = [$sql_constraint] if ref $sql_constraint ne 'ARRAY';
  for my $sql (@$sql_constraint) {
    $sql ||= 'FALSE';
    $constraint .= " ($sql) and";
  }

  $self->{_constraints} = $constraint;
  return $constraint;
}

=head1 _q, _qi

SQL quoting shortcuts

=cut

sub _q { $_[0]->{_session}->db->quote(@_[1..$#_]); }
sub _qi { $_[0]->{_session}->db->quote_identifier(@_[1..$#_]); }

sub _table {
  my $self = shift;
  return $self->{_table};
}
sub _tablename {
  my $self = shift;
  return $self->{_tablename};
}

sub _cols_values_lists {
  my $self = shift;
  my $sql='';
  my $sqlVal='';

  for my $col (@{$self->{_cols}}) {
    next if $col eq "id";
    next if !exists $self->{$col};
    $self->{$col} = $self->resolve_ref($self->{$col});

    $sql .= $col.",";
    if (!defined($self->{$col})) {
      $sqlVal .= "NULL,";
    }
    else {
      $sqlVal .= $self->{_session}->db->quote($self->{$col}).",";
    }
  }
  $sql =~ s/,$//;
  $sqlVal =~ s/,$//;
  return ($sql, $sqlVal);
}

sub _cols_values {
  my $self = shift;
  my $sql = '';  
  for my $col (@{$self->{_cols}}) {
    next if $col eq "id";
    next if !exists $self->{$col};
    $self->{$col} = $self->resolve_ref($self->{$col});

    if (!defined($self->{$col})) {
      $sql .= $col."=NULL, ";
    } 
    else {
      $sql .= $col."=".$self->{_session}->db->quote($self->{$col}).", ";
    }
  }
  $sql =~ s/, $//;
  return $sql;
}

sub _mappings {
  my $self = shift;
  my @cols = @_ ? map {$self->_convert_col($_)} @_ : @{$self->{_cols}};
  my $sql = '';

  for (@cols) { 
    next if !exists($self->{$_});

    if (!defined($self->{$_})) {
      $sql .= " ".$_." is NULL and";
    }
    else {
      $sql .= " ".$_."=".$self->{_session}->db->quote($self->{$_})." and";
    }
  }
  return $sql;
}

sub _cols_list {
  my $self = shift;
  return join(",", @{$self->{_cols}});
}

sub _nextval {
  my $self = shift;
  my $col = shift || 'id';
  $col = $self->_convert_col($col);
  my $tablename = $self->{_tablename} =~ /^"(.*)"$/ ? $1 : $self->{_tablename};
  my $nextval =  ($self->{_schema} ? ($self->_qi($self->{_schema}).'.') : '')
    ."${tablename}_${col}_seq";
  return $nextval;
}

=head1 _cleanup

Clean up ending where's and and's from sql string

=cut

sub _cleanup {
  my $self = shift;
  my ($sql) = @_;
  $sql =~ s/ where$//;
  $sql =~ s/ and$//;
  return $sql;
}

=head1 session

  returns the session object

=cut

sub session
{
  return shift->{_session};
}

sub cols {
  my $self = shift;
  return @{$self->{_cols}||[]};
}

sub has_col {
  my $self = shift;
  my $col = shift;
  return $self->{_session}{cols_hash}{$self->{_module}}{$col}
    || $self->{_session}{lccols_hash}{$self->{_module}}{lc($col)}
    || exists($self->{$col});
}

=head1 resolve_ref

  internal convenience routine for finding the eventual value of
  a scalar reference.

=cut

sub resolve_ref
{
   my $self = shift;
   my $thingy = shift;
   my  %seen = ();
   while ( ref($thingy) eq "SCALAR") {
      $self->{_session}->log($Session::Verbose,"Resolving scalar referance.");
      $self->{_session}->error("Circular Reference","Scalar reference loop.")
        if ( $seen{$thingy});
      $seen{$thingy} = 1;
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
   $name = $self->_convert_col($name);
   if (!$self->has_col($name)) {
     $self->{_session}->error("$name is not a column for ".ref($self).".");
   }
   return \$self->{$name};
}

=head1 is_null

Tests if a value has been explicitly set to NULL

=cut

sub is_null 
{
  my $value = $_[-1];
  return !defined($value);
}

sub AUTOLOAD
{
  my $self = shift;
  croak "$self is not an object." unless ref($self);
  my $name = $DbObject::AUTOLOAD;
  $name =~ s/.*://;

  return $self->col($name, @_);
}

sub col {
  my $self = shift;
  my $name = shift;

  $name = $self->_convert_col($name);
  if (!$self->has_col($name)) {
    $self->{_session}->die("$name is not a method for ".ref($self).".");
  }
  $self->{$name} = shift @_ if ( @_ );
  return $self->{$name};
}

sub DESTROY {}

=head1 Private routines

  These are not intended to be called except by internal classes

=cut

=head1  _convert_col

Perform case-sensitive conversion of column names in the
arguments hash.

=cut

sub _convert_col {
  my $self = shift;
  my ($obj) = @_;
  return $obj if !defined $obj;

  my $cols_hash = $self->{_session}->{cols_hash}->{$self->{_module}};
  my $lccols_hash = $self->{_session}->{lccols_hash}->{$self->{_module}};
  $obj =~ s/^-//;
  $obj = $cols_hash->{$obj} 
    || $lccols_hash->{lc($obj)} 
    || $cols_hash->{$self->_qi($obj)} 
    || $lccols_hash->{$self->_qi(lc($obj))} 
    || $obj;
  return $obj;
}

=head1 _dump_fields

  used in generating ascii dumps for loading/unloading. Returns a string
  of record values with tab delimiters and \N's for nulls.
=cut

sub _dump_fields
{
  my $self = shift;

  my $return;
  for my $col (@{$self->{_cols}}) {
    my $val = $self->{$col};
    if (defined($val)) {
      $val =~ s/\x08/\\b/sg;
      $val =~ s/\x0c/\\f/sg;
      $val =~ s/\x0a/\\n/sg;
      $val =~ s/\x09/\\t/sg;
      $val =~ s/\x0b/\\v/sg;
    } 
    else {
      $val = "\\N";
    }
    $return .= "\t" if $return;
    $return .= $val;
  }
  return $return;
}

1;

