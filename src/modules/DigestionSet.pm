package DigestionSet;

=head1 Name

   DigestionSet.pm   A module for the db interface for sets of digestion thingies.

=head1 Usage

   use DigestionSet;
   $digestionSet = new DigestionSet([options]);

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
