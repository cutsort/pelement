package Seq_Alignment;

=head1 Name

   Seq_Alignment.pm A module for the encapsulation of Seq_Alignment information

=head1 Usage

  use Seq_Alignment;
  $Seq_Alignment = new Seq_Alignment($session,{-key1=>val1,-key2=>val2...});

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
