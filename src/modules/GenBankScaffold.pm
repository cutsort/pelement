package GenBankScaffold;

=head1 Name

   GenBankScaffold.pm A module for the encapsulation of genbank scaffold information

=head1 Usage

  use GenBankScaffold;
  $gb = new GenBankScaffold($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use DbObject;

=head1 mapped_from_arm

   Select a scaffold based on an arm and coordinate. Only the first is returned
   if there are multiple.

   This routine relies on the SQL function get_scaffold on the server

=cut

sub mapped_from_arm
{
   my $self = shift;

   my $arm = shift;
   my $coordinate = shift;

   $self->accession( 
        $self->session->db->select_value("select get_scaffold(".
                                     $self->session->db->quote($arm).
                                         ",$coordinate)"));
   $self->select;
   return $self;
}
1;

