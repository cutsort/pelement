package XML::GenomePosition;

=head1 Name

   XML::GenomePosition.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::GenomePosition;
   $thing = new XML::GenomePosition({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::Insertion;

BEGIN {
   @XML::GenomePosition::AttributeRequiredList = qw(genome_version arm location);
   @XML::GenomePosition::ElementRequiredList = qw();
   %XML::GenomePosition::AttributeOptionHash = ();
   @XML::GenomePosition::AttributeOptionalList = qw(strand comment);
   @XML::GenomePosition::ElementList = qw();
   @XML::GenomePosition::ElementListList = qw();
}
1;
