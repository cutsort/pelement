package GelSet;

=head1 Name

   GelSet.pm   A module for the db interface for sets of gel thingies.

=head1 Usage

   use GelSet;
   $gelSet = new GelSet([options]);

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
