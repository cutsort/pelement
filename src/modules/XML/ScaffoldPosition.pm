package XML::ScaffoldPosition;

=head1 Name

   XML::ScaffoldPosition.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::ScaffoldPosition;
   $thing = new XML::ScaffoldPosition({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::GBAccno;

BEGIN {
   @XML::ScaffoldPosition::AttributeRequiredList = qw(location);
   @XML::ScaffoldPosition::ElementRequiredList = qw(XML::GBAccno);
   %XML::ScaffoldPosition::AttributeOptionHash = (strand => [qw(p m)]);
   @XML::ScaffoldPosition::AttributeOptionalList = qw(strand comment);
   @XML::ScaffoldPosition::ElementList = qw(XML::GBAccno);
   @XML::ScaffoldPosition::ElementListList = qw();
}

1;
