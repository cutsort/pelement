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
use base 'DbObjectSet';

1;


