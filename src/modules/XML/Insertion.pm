package XML::Insertion;

=head1 Name

   XML::Insertion.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::Insertion;
   $thing = new XML::Insertion({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::InsertionData;
use XML::Stock;

BEGIN {
   @XML::Insertion::AttributeRequiredList = qw(transposon_symbol);
   @XML::Insertion::ElementRequiredList = qw(XML::InsertionData);
   %XML::Insertion::AttributeOptionHash = ();
   @XML::Insertion::AttributeOptionalList = qw(insertion_symbol fbti comment);
   @XML::Insertion::ElementList = qw();
   @XML::Insertion::ElementListList = qw(XML::InsertionData XML::Stock);
}

1;
