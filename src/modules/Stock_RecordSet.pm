package Stock_RecordSet;

=head1 Name

   Stock_RecordSet.pm   A module for the db interface for sets of stock record thingies.

=head1 Usage

   use Stock_RecordSet;
   $sRSet = new Stock_RecordSet([options]);

=cut

use strict;
use Pelement;
use PCommon;
use base 'DbObjectSet';

1;
