package Blast_HitSet;

=head1 Name

   Blast_HitSet.pm   A module for the db interface for sets of blast thingies.

=head1 Usage

   use Blast_HitSet;
   $blastSet = new Blast_HitSet([options]);

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
