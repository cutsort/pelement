
=head1 Name

  DbObjectCursor.pm Cursor implementation for DbObject

=cut

package DbObjectCursor;
use DbObject;
use base 'DbObjectSet';
use strict;

our $fetch_size = 1000;
our $direction = '';

sub new
{
  my $class = shift;
  my $session = shift || die "Session argument required.";
  my $args = shift;

  my $fetch_size = DbObject::_extract_args($args, 'fetch_size') || $fetch_size;
  my $direction = DbObject::_extract_args($args, 'direction') || $direction;
  my $self = initialize_self($class,$session,$args);

  $self->{_objects} = [];
  $self->{_cursor_num} = $session->{_cursor_inc} || 0;
  $self->{_cursor_open} = '';
  $session->{_cursor_inc}++;

  $self->{_fetch_size} = $fetch_size;
  $self->{_direction} = $direction;
  return $self;
}

sub initialize_self {
  my ($class, $session, $args) = @_;
  (my $module = $class) =~ s/Cursor$//;
  return DbObject::initialize_self($class,$session,$args,$module);
}

sub DESTROY {
  my $self = shift;
  $self->close;
}

=head1 open

Close and re-open a cursor, and return one fetch

=cut

sub open {
  my $self = shift;
  my $session = $self->{_session} || 
    die "Session handle required db selection";
  return unless $self->{_table} && $self->{_cols} && $self->{_module};

  my $sql = $self->get_sql;
  $session->log($Session::SQL,"Cursor SQL: $sql.");

  my $cursor_name = 'csr_'.$self->{_cursor_num};
  $self->close if $self->{_cursor_open};
  $session->db->do("DECLARE $cursor_name SCROLL CURSOR WITH HOLD FOR $sql");
  $self->{_cursor_open} = 1;
  return $self;
}

=head1 select

Fetch from an open cursor. From Postgres docs:

FETCH [ direction { FROM | IN } ] cursorname

where direction can be empty or one of:

    NEXT
    PRIOR
    FIRST
    LAST
    ABSOLUTE count
    RELATIVE count
    count
    ALL
    FORWARD
    FORWARD count
    FORWARD ALL
    BACKWARD
    BACKWARD count
    BACKWARD ALL

=cut

sub select {
  my $self = shift;
  my $args = shift || {};

  my $session = $self->{_session} || 
    die "Session handle required db selection";

  $self->open if !$self->is_open;

  my $module = $self->{_module};
  $session->table($module);

  my $fetch_size = DbObject::_extract_args($args, 'fetch_size') || $self->{_fetch_size} || $fetch_size;
  my $direction = DbObject::_extract_args($args, 'direction') || $self->{_direction} || $direction;
  $session->die("Invalid arguments passed to select for ".ref($self).": ".join(',',keys %$args))
    if keys %$args;
  my $cursor_name = 'csr_'.$self->{_cursor_num};
  my $st = $session->db->prepare("FETCH $direction $fetch_size FROM $cursor_name");
  $st->execute;

  # save the fetch size and direction if changed
  $self->{_fetch_size} = $fetch_size;
  $self->{_direction} = $direction;

  $self->{_objects} = [];
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

sub is_open { $_[0]->{_cursor_open} }

sub close {
  my $self = shift;
  my $session = $self->{_session} || return;
  if ($self->{_cursor_open}) {
    my $cursor_name = 'csr_'.$self->{_cursor_num};
    $session->db->do("CLOSE $cursor_name");
    $self->{_cursor_open} = '';
  }
  return $self;
}

1;

