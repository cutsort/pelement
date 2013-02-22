package Strain_Alias;

=head1 Name

   Strain_Alias.pm A module for the encapsulation of strain alias processing information

=head1 Usage

  use Strain_Alias;
  $alias = new Strain_Alias($session,{-key1=>val1,-key2=>val2...});

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

