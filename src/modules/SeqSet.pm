package SeqSet;

=head1 Name

   SeqSet.pm   A module for the db interface for sets of seq thingies.

=head1 Usage

   use SeqSet;
   $seqSet = new SeqSet([options]);

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
