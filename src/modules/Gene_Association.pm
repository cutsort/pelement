package Gene_Association;

=head1 Name

   Gene_Association.pm A module for the encapsulation of gene association processing information

=head1 Usage

  use Gene_Association;
  $gene_association = new Gene_Association($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use DbObject;

1;

