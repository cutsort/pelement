package XML::Stock;

=head1 Name

   XML::Stock.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::Stock;
   $thing = new XML::Stock({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;

BEGIN {
   @XML::Stock::AttributeRequiredList = qw(stock_center stock_id);
   @XML::Stock::ElementRequiredList = qw();
   %XML::Stock::AttributeOptionHash = ();
   @XML::Stock::AttributeOptionalList = qw(comment);
   @XML::Stock::ElementList = qw();
   @XML::Stock::ElementListList = qw();
}

1;
