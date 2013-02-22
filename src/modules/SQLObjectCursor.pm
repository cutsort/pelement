
=head1 Name

  SQLObjectCursor.pm Cursor implementation for DbObject

=cut

package SQLObjectCursor;
use SQLObject;
use base 'SQLObjectSet';
use strict;

our $fetch_size = 1000;
our $direction = '';

sub new
{
  my $class = shift;
  my $session = shift || die "Session argument required.";
  my $sql = shift || '';
  my $args = shift || {};

  my $self = $class->SQLObjectSet::new($session, $sql, $args, @_);

  (my $base = $class) =~ s/Cursor$//;
  $self->{_base} = $base;

  $self->{_cursor_num} = $session->{_cursor_inc} || 0;
  $session->{_cursor_inc}++;
  $self->{_fetch_size} = delete $args->{'-fetch_size'} || delete $args->{fetch_size} || $fetch_size;
  $self->{_direction} = delete $args->{'-direction'} || delete $args->{direction} || $direction;
  $session->die("Invalid arguments passed to ".ref($self).": ".join(',',keys %$args))
    if keys %$args;

  return $self;
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

  my $sql = $self->{_sql};
  $session->log($Session::SQL,"Cursor SQL: $sql.");

  my $cursor_name = 'csr_'.$self->{_cursor_num};
  $self->close if $self->{_cursor_open};
  $session->db->do("DECLARE $cursor_name SCROLL CURSOR WITH HOLD FOR $sql", 
    undef, @{$self->{_bind_params}||[]});
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

  # do we need to load a class for the base object?
  my $class = $self->{_base};
  eval { require $class.'.pm'};
  if ($@) {
    eval "{package $class; use base 'SQLObject'; }";
  }

  $self->open if !$self->is_open;

  my $module = $self->{_module};

  my $fetch_size = delete $args->{'-fetch_size'} || delete $args->{fetch_size} || $self->{_fetch_size} || $fetch_size;
  my $direction = delete $args->{'-direction'} || delete $args->{direction} || $self->{_direction} || $direction;
  $session->die("Invalid arguments passed to ".ref($self).": ".join(',',keys %$args))
    if keys %$args;
  my $cursor_name = 'csr_'.$self->{_cursor_num};
  my $st = $session->db->prepare("FETCH $direction $fetch_size FROM $cursor_name");
  $st->execute(@_);

  # save the fetch size and direction if changed
  $self->{_fetch_size} = $fetch_size;
  $self->{_direction} = $direction;

  $self->{_objects} = [];
  no strict 'refs';
  while ( my $href = $st->fetchrow_arrayref() ) {
    my $new_self = $class->new($session, $self);

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

