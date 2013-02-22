=head1 Name

   Blast_HSP.pm A module for the encapsulation of gel processing information

=head1 Usage

  use Blast_HSP;
  $blastHsp = new Blast_HSP($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

package Blast_HSP;

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use base 'DbObject';

1;
