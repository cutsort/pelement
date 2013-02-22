package Digestion;

=head1 Name

   Digestion.pm A module for the encapsulation of digestion processing information

=head1 Usage

  use Digestion;
  $digestion = new Digestion($session,{-key1=>val1,-key2=>val2...});

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
