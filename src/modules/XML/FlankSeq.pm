package XML::FlankSeq;

=head1 Name

   XML::FlankSeq.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::FlankSeq;
   $thing = new XML::FlankSeq({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::GBAccno;

BEGIN {
   @XML::FlankSeq::AttributeRequiredList = qw(flanking position_of_first_base_of_target_sequence);
   @XML::FlankSeq::ElementRequiredList = qw(XML::GBAccno);
   %XML::FlankSeq::AttributeOptionHash = (flanking => [qw(5 3 b)]);
   @XML::FlankSeq::AttributeOptionalList = qw(comment);
   @XML::FlankSeq::ElementList = qw(XML::GBAccno);
   @XML::FlankSeq::ElementListList = qw();
}

1;
