=head1 Name

   Blast_Run.pm A module for the encapsulation of Blast_Run information

=head1 Usage

  use Blast_Run;
  $blastRun = new Blast_Run($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

package Blast_Run;

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use DbObject;

1;
