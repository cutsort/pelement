package StrainSet;

=head1 Name

   StrainSet.pm   A module for the db interface for sets of seq thingies.

=head1 Usage

   use StrainSet;
   $seqSet = new StrainSet([options]);

=cut

use strict;
use Pelement;
use PCommon;
use base 'DbObjectSet';

1;
