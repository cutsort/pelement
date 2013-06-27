package GenBank_Submission_InfoSet;

=head1 Name

   GenBank_Submission_InfoSet.pm   A module for the db interface for sets of genbank_submission_info thingies.

=head1 Usage

   use GenBank_Submission_InfoSet;
   $laneSet = new GenBank_Submission_InfoSet([options]);

=cut

use strict;
use Pelement;
use PCommon;
use base 'DbObjectSet';

1;
