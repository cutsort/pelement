package Cytology;

=head1 Name

   Cytology.pm A module for the encapsulation of cytology processing information

=head1 Usage

  use Cytology;
  $cytology = new Cytology($session,{-key1=>val1,-key2=>val2...});

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

