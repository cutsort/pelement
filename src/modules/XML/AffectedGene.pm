package XML::AffectedGene;

=head1 Name

   XML::AffectedGene.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::AffectedGene;
   $thing = new XML::AffectedGene({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::LocalGene;

BEGIN {
   @XML::AffectedGene::AttributeRequiredList = qw();
   @XML::AffectedGene::ElementRequiredList = qw(XML::LocalGene);
   %XML::AffectedGene::AttributeOptionHash = (rel_orientation => [qw(p m)]);
   @XML::AffectedGene::AttributeOptionalList = qw(rel_orientation distance_to_transcript_5 distance_to_transcript_3 comment);
   @XML::AffectedGene::ElementList = qw(XML::LocalGene);
   @XML::AffectedGene::ElementListList = qw();
}

1;
