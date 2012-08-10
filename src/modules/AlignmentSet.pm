=head1 Name

   AlignmentSet.pm  A module for manipulating a set sequence alignment

=head1 Usage

   use AlignmentSet;
   $alignSet = new AlignmentSet($session,[options])


=head1 Options


=cut

package AlignmentSet;

use strict;
use Pelement;
use PCommon qw(parseArgs);
use Session;
use PelementDBI;
use Alignment;

=head1 Public Methods

=cut

sub new 
{
  my $class = shift;
  my $session = shift || new Session({-useDb=>0});
  # an optional hash ref of arguments
  my $args = shift || {};

  my $self = {
              session => $session,
              p_name =>  parseArgs($args,'seq_name') || parseArgs($args,'p_name')   || "",
              p_start => parseArgs($args,'p_start')  || "",
              p_end =>   parseArgs($args,'p_end')    || "",
              s_name =>  parseArgs($args,'scaffold') || parseArgs($args,'s_name') || "",
              s_start => parseArgs($args,'s_start')  || "",
              s_end =>   parseArgs($args,'s_end')    || "",
              alignments => [],
             };

  return bless $self, $class;
}

=head1 select

  This can either be called as a class or object method. If we have
  not instantiated the class yet, we'll do so and read from the db

=cut


sub select
{
  my $self = shift;
  $self = new AlignmentSet(@_) unless ref($self);

  # clear out old alignments in case we've already read them
  $self->{alignments} = [];

  $self->session->error("No db handle present for reading alignment")
                                                        unless $self->session->db;
 
  my $sql = $self->select_sql();

  $self->session->log($Session::Info,"Sql: $sql");

  my @results = ();
  $self->session->db->select($sql,\@results);
  while( @results ) {
     my ($seq_name,$scaffold,$p_start,$p_end,$s_start,$s_end) = splice(@results,0,6);
     push @{$self->alignments}, new Alignment($self->session,
                              {p_name  =>  $seq_name,
                               s_name  =>  $scaffold,
                               p_start =>  $p_start,
                               p_end   =>  $p_end,
                               s_start =>  $s_start,
                               s_end   =>  $s_end,});
  }
  return $self;
}

=head1 select_sql

   Generate the sql to select the current alignment set

=cut

sub select_sql
{
  my $self = shift;

  my $sql = qq(select seq_name,scaffold,p_start,p_end,s_start,s_end from seq_alignment
               where);
  $sql .= " seq_name=".$self->session->db->quote($self->p_name)." and " if $self->p_name;
  $sql .= " scaffold=".$self->session->db->quote($self->s_name)." and " if $self->s_name;
  foreach my $var (qw(p_start s_start)) {
     $sql .= " $var>= ".$self->{$var}." and " if $self->{$var};
  }
  foreach my $var (qw(p_end s_end)) {
     $sql .= " $var<= ".$self->{$var}." and " if $self->{$var};
  }
  $sql =~ s/ and $//;
  $sql =~ s/where$//;
  return $sql;
}


sub get_alignments { return shift->{alignments}; }
sub alignments { return shift->{alignments}; }
sub get_session { return shift->{session}; }
sub session { return shift->{session}; }

sub get_s_name { return shift->{s_name}; }
sub s_name { return shift->{s_name}; }
sub get_s_start { return shift->{s_start}; }
sub s_start { return shift->{s_start}; }
sub get_s_end { return shift->{s_end}; }
sub s_end { return shift->{s_end}; }

sub get_p_name { return shift->{p_name}; }
sub p_name { return shift->{p_name}; }
sub get_p_start { return shift->{p_start}; }
sub p_start { return shift->{p_start}; }
sub get_p_end { return shift->{p_end}; }
sub p_end { return shift->{p_end}; }


1;
