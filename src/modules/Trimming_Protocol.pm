package Trimming_Protocol;

=head1 Name

   Trimming_Protocol.pm A module for the encapsulation of trimming protocol
   processing information

=head1 Usage

  use Trimming_Protocol;
  $t_p = new Trimming_Protocol($session,{-key1=>val1,-key2=>val2...});

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

