=head1 Name

   Alignment.pm  A module for manipulating a single sequence alignment

=head1 Usage

   use Alignment;
   $align = new Alignment($session,[options])

   This object would typically be invoked by the AlignmentSet module when
   generating a list of stored alignment

=head1 Options


=cut

package Alignment;

use strict;
use Pelement;
use PCommon qw(parseArgs);
use PelementDBI;

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
              p_name =>  parseArgs($args,'p_name')  || "",
              p_start => parseArgs($args,'p_start') || "",
              p_end =>   parseArgs($args,'p_end')   || "",
              s_name =>  parseArgs($args,'s_name')  || "",
              s_start => parseArgs($args,'s_start') || "",
              s_end =>   parseArgs($args,'s_end')   || "",
             };

  return bless $self, $class;
}

=head1 select

  Retrieve the alignment information about 1 sequence alignment
  based on 1) the parameters specified in an already created alignment
  object or 2) optional specified arguments. In the latter cases a new
  object is created and returned. 

=cut

sub select
{

  my $self = shift;
  $self = new Alignment(@_) unless ref($self);

  $self->session->error("No db handle present for reading alignment")
                                                        unless $self->session->db;

  my $sql = $self->select_sql();
  $self->session->log($Session::Info,"Sql: $sql");
  my @results = ();
  $self->session->db->select($sql,\@results);
  ($self->{p_name},$self->{s_name},$self->{p_start},
       $self->{p_end},$self->{s_start},$self->{s_end}) = splice(@results,0,6);

}

=head1 select_sql

  Generate the sql based on the current selection criteria

=cut

sub select_sql
{
  my $self = shift;
  
}

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
sub q_end { return shift->{p_end}; }


1;
