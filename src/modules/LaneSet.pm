package LaneSet;

=head1 Name

   LaneSet.pm   A module for the db interface for sets of lane thingies.

=head1 Usage

   use LaneSet;
   $laneSet = new LaneSet([options]);

=cut

use strict;
use Pelement;
use PCommon;
use DbObjectSet;

sub new 
{
  my $class = shift;
  my $session = shift;
  my $args = shift;

  my $self = initialize_self($class,$session,$args);

  return bless $self,$class;

}
    
1;
