package LigationSet;

=head1 Name

   LigationSet.pm   A module for the db interface for sets of ligation thingies.

=head1 Usage

   use LigationSet;
   $ligationSet = new LigationSet([options]);

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
