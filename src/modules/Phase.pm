package Phase;

=head1 Name

   Phase.pm A module for the encapsulation of seq information

=head1 Usage

  use Phase;
  $phase = new Phase($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use DbObject;

1;
