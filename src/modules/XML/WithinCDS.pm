package XML::WithinCDS;

=head1 Name

   XML::WithinCDS.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::WithinCDS;
   $thing = new XML::WithinCDS({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::LocalGene;

BEGIN {
   @XML::WithinCDS::AttributeRequiredList = qw();
   @XML::WithinCDS::ElementRequiredList = qw(XML::LocalGene);
   %XML::WithinCDS::AttributeOptionHash = (rel_orientation => [qw(p m)]);
   @XML::WithinCDS::AttributeOptionalList = qw(rel_orientation distance_to_transcript_5 distance_to_transcript_3 comment);
   @XML::WithinCDS::ElementList = qw(XML::LocalGene);
   @XML::WithinCDS::ElementListList = qw();
}


1;
