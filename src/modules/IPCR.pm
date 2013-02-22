package IPCR;

=head1 Name

   IPCR.pm A module for the encapsulation of inverse PCR thingies 

=head1 Usage

  use IPCR;
  $ipcr = new IPCR($session,{-key1=>val1,-key2=>val2...});

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
