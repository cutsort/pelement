package Blast_OptionSet;

=head1 Name

   Blast_OptionSet.pm   A module for the db interface for sets of blast option thingies.

=head1 Usage

   use Blast_OptionSet;
   $blast_optionSet = new Blast_OptionSet([options]);

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
