=head1 Name

   Blast_Hit.pm A module for the encapsulation of Blast_Hit information

=head1 Usage

  use Blast_Hit;
  $blastHit = new Blast_Hit($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

package Blast_Hit;

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use base 'DbObject';

1;
