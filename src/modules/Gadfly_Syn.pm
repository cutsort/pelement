package Gadfly_Syn;

=head1 Name

   Gadfly_Syn.pm A module for the encapsulation of gadfly_syn thingies

=head1 Usage

  use Gadfly_Syn;
  $gadfly_syn = new Gadfly_Syn($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use base 'DbObject';

1;
