=head1 Name

   Blast_ReportSet.pm   A module for the db interface for sets of Blast report thingies.

=head1 Usage

   use Blast_ReportSet;
   $blastReportSet = new Blast_ReportSet([options]);

=cut

package Blast_ReportSet;

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use DbObjectSet;

=head1

   new create a generic set of db rows.

=cut 

sub new
{
  my $class = shift;
  my $session = shift;
  my $args = shift;

  my $self = initialize_self($class,$session,$args);

  return bless $self,$class;

}

1;


