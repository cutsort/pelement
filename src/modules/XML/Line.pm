package XML::Line;

=head1 Name

   XML::Line.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::Line;
   $thing = new XML::Line({attribute=>value});
   $thing->add(new Child);

   $error = $thing->validate;

   $thing->to_xml

=cut

use XML::Base;
use XML::Insertion;


BEGIN {
   @XML::Line::AttributeRequiredList = qw(line_id);
   @XML::Line::ElementRequiredList = qw(XML::Insertion);
   %XML::Line::AttributeOptionHash = (is_multiple_insertion_line => [qw(Y P N)]);
   @XML::Line::AttributeOptionalList = qw(is_multiple_insertion_line comment line_id_synonym);
   @XML::Line::ElementList = qw();
   @XML::Line::ElementListList = qw(XML::Insertion);
}

1;
