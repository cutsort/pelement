=head1 Name

   Seq_AlignmentSet.pm   A module for the db interface for sets of Seq_Alignment thingies.

=head1 Usage

   use Seq_AlignmentSet;
   $seqAlignmentSet = new Seq_AlignmentSet([options]);

=cut

package Seq_AlignmentSet;

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use DbObjectSet;

=head1

   new create a generic set of db rows.

=cut 

sub new
{
  my $class = shift;
  my $session = shift;
  my $args = shift;

  my $self = initialize_self($class,$session,$args);

  return bless $self,$class;

}

1;


