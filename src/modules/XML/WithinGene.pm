package XML::WithinGene;

=head1 Name

   XML::WithinGene.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::WithinGene;
   $thing = new XML::WithinGene({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::LocalGene;

BEGIN {
   @XML::WithinGene::AttributeRequiredList = qw();
   @XML::WithinGene::ElementRequiredList = qw(XML::LocalGene);
   %XML::WithinGene::AttributeOptionHash = (rel_orientation => [qw(p m)]);
   @XML::WithinGene::AttributeOptionalList = qw(rel_orientation distance_to_transcript_5 distance_to_transcript_3 comment);
   @XML::WithinGene::ElementList = qw(XML::LocalGene);
   @XML::WithinGene::ElementListList = qw();
}

1;
