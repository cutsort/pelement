package Ligation;

=head1 Name

   Ligation.pm A module for the encapsulation of ligation processing information

=head1 Usage

  use Ligation;
  $ligation = new Ligation($session,{-key1=>val1,-key2=>val2...});

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
