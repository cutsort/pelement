package XML::WithinTranscript;

=head1 Name

   XML::WithinTranscript.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::WithinTranscript;
   $thing = new XML::WithinTranscript({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::LocalGene;

BEGIN {
   @XML::WithinTranscript::AttributeRequiredList = qw();
   @XML::WithinTranscript::ElementRequiredList = qw(XML::LocalGene);
   %XML::WithinTranscript::AttributeOptionHash = (rel_orientation => [qw(p m)]);
   @XML::WithinTranscript::AttributeOptionalList = qw(rel_orientation distance_to_transcript_5 distance_to_transcript_3 comment);
   @XML::WithinTranscript::ElementList = qw(XML::LocalGene);
   @XML::WithinTranscript::ElementListList = qw();
}

1;
