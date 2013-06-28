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
use Session;
use Carp;
use base 'DbObject';
use strict;
use warnings;

sub new
{
  my $class = shift;
  my $session = shift || die "Session argument required.";
  my $args = shift;

  my $self = initialize_self($class,$session,$args);

  $self->{_objects} = [];
  return $self;
}

sub initialize_self {
  my ($class, $session, $args) = @_;
  (my $module = $class) =~ s/Set$//;
  return DbObject::initialize_self($class,$session,$args,$module);
}

=head1

calls a "select count(*)" query that returns the number of rows in this query's
result set.

=cut

sub count_rows {
  my $self = shift;
  $self->db_exists(@_);
}

=head1

   select Based on the filled fields, a database record is selected which
   matches the non-null fields. The returned record must be unique.

   TODO: specify additional qualifiers.

=cut

sub select {
  my $self = shift;
  my $session = $self->{_session} 
    || die "Session handle required db selection";
  return unless $self->{_table} && $self->{_cols} && $self->{_module};

  # load the table's package into memory
  my $module = $self->{_module};
  $session->table($module);

  # apply rewrite rules if needed
  $self->rewrite;
  
  my ($st, $sql) = $self->perform_select();
  $session->log($Session::SQL,"SQL: $sql.");

  no strict 'refs';
  while ( my $href = $st->fetchrow_arrayref() ) {
    my $new_self = $module->new($session);

    my $ctr = 0;
    $new_self->{$_} = $href->[$ctr++] for @{$self->{_cols}};

    push @{$self->{_objects}}, $new_self;
  }
  $st->finish;
  return $self;
}

sub rewrite {
  # the default rewrite rule is to do nothing.
  my $self = shift;
  return $self;
}


=head1 session

  returns the session object

=cut

sub session {
  return shift->{_session};
}

sub as_list {
  return @{shift->{_objects}};
}

sub as_list_ref {
  return shift->{_objects};
}

=head1 add

  Add an object to the set. This does not save it in the db, only
  puts it in the container.

=cut

sub add {
   my $self = shift;
   my $new_obj = shift;

   $self->{_session}->die("$new_obj is not a ".$self->{_module}." object.")
     if ref($new_obj) ne $self->{_module};
   push @{$self->{_objects}}, $new_obj;
}

=head1 unshift_obj

  Kinda like add, but puts it at the top of the list

=cut

sub unshift_obj {
   my $self = shift;
   my $new_obj = shift;

   $self->{_session}->die("$new_obj is not a ".$self->{_module}." object.")
     if ref($new_obj) ne $self->{_module};
   unshift @{$self->{_objects}}, $new_obj;
}


=head1 remove

Removes the object from the container. The (smaller) container
is returned. The db record is not deleted.

=cut

sub remove {
  my $self = shift;
  my $obj = shift;

  for( my $i=0;$i<=$#{$self->{_objects}};) {
    if ($self->{_objects}->[$i] eq $obj) {
      splice(@{$self->{_objects}},$i,1);
    } 
    else {
      $i++;
    }
  }
  return $self;
}

=head1 shift_obj

Remove one object from the container and return the removed object. Useful
when processing all objects in a container, but the order is not
guaranteed

This is not called shift because of tedious name collision with CORE::shift

=cut

sub shift_obj {
  my $self = shift;

  return if $#{$self->{_objects}} < 0;
  my $obj = $self->{_objects}->[0];
  $self->remove($obj);
  return $obj;
}

=head1 insert, delete

  Without verifying if these record already exists, insert or delete the records
  one by one

=cut

sub insert {
   my $self = shift;
   $_->insert(@_) for @{$self->{_objects}};
   return $self;
}

sub delete {
   my $self = shift;
   $_->delete(@_) for @{$self->{_objects}};
   return $self;
}

=head1 count

  Hommany object we got. Not a DB query!

=cut

sub count {
  my $self = shift;
  return scalar(@{$self->{_objects}});
}

=head1 _dbg_print

This is normally only used as part of debugging for printing fields.

=cut

sub _dump_fields {
  my $self = shift;
  my $return = join("\t",@{$self->{_cols}})."\n";
  $return .= $_->_dump_fields."\n" for $self->as_list;
  return $return;
}

sub select_if_exists { $_[0]->{_session}->die("Operation not supported") }
sub select_or_die { $_[0]->{_session}->die("Operation not supported") }
sub unique_identifier { $_[0]->{_session}->die("Operation not supported") }
sub insert_or_update { $_[0]->{_session}->die("Operation not supported") }
sub insert_or_ignore { $_[0]->{_session}->die("Operation not supported") }
sub get_next_id { $_[0]->{_session}->die("Operation not supported") }
sub set_id { $_[0]->{_session}->die("Operation not supported") }

sub DESTROY {}

1;

