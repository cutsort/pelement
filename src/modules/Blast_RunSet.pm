package Blast_RunSet;

=head1 Name

   Blast_RunSet.pm   A module for the db interface for sets of blast thingies.

=head1 Usage

   use Blast_RunSet;
   $blastSet = new Blast_RunSet([options]);

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
