=head1 Name

   Association.pm  A module for manipulating a single gene Association

=head1 Usage

   use Association;
   $align = new Association($session,[options])

=head1 Options


=cut

package Association;

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
              seq_name   => parseArgs($args,'seq_name')  || "",
              cg_name    => parseArgs($args,'cg_name')  || "",
              dist_to_cg => parseArgs($args,'dist_to_cg') || "",
             };

  return bless $self, $class;
}

sub write
{
  my $self = shift;
  $self = new Association(@_) unless ref($self);

  $self->session->error("No DB","No db handle present for reading alignment")
                                                        unless $self->session->db;

  my $sql = qq(insert into p_insertion_to_cg (seq_name,cg_name,dist_to_cg) values ).
            "(".$self->session->db->quote($self->{seq_name})   .",".
                $self->session->db->quote($self->{cg_name})    .",".
                $self->session->db->quote($self->{dist_to_cg}) .")";

  $self->session->db->do($sql);

}

sub get_session { return shift->{session}; };
sub session { return shift->{session}; };
sub get_seq_name { return shift->{seq_name}; }
sub seq_name { return shift->{seq_name}; }
sub get_cg_name { return shift->{cg_name}; }
sub cg_name { return shift->{cg_name}; }
sub get_dist_to_cg { return shift->{dist_to_cg}; };
sub dist_to_cg { return shift->{dist_to_cg}; };


1;
