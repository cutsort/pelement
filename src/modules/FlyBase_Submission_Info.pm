package FlyBase_Submission_Info;

=head1 Name

   FlyBase_Submission_Info.pm A module for the encapsulation of submit_info processing information

=head1 Usage

  use FlyBase_Submission_Info;
  $submit_info = new FlyBase_Submission_Info($session,{-key1=>val1,-key2=>val2...});

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

