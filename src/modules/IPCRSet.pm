package IPCRSet;

=head1 Name

   IPCRSet.pm   A module for the db interface for sets of ipcr thingies.

=head1 Usage

   use IPCRSet;
   $ipcrSet = new IPCRSet([options]);

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
