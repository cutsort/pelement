package PhaseSet;

=head1 Name

   PhaseSet.pm   A module for the db interface for sets of phase thingies.

=head1 Usage

   use PhaseSet;
   $phaseSet = new PhaseSet([options]);

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
