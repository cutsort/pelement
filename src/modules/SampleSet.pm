package SampleSet;

=head1 Name

   SampleSet.pm   A module for the db interface for sets of sample thingies.

=head1 Usage

   use SampleSet;
   $sampleSet = new SampleSet([options]);

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
