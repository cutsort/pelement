package XML::Complementation;

=head1 Name

   XML::Complementation.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::Complementation;
   $thing = new XML::Complementation({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;

BEGIN {
   @XML::Complementation::AttributeRequiredList = qw(comp_type fbal);
   @XML::Complementation::ElementRequiredList = qw();
   %XML::Complementation::AttributeOptionHash = (comp_type => [qw(complements fails)]);
   @XML::Complementation::AttributeOptionalList = qw(allele_symbol aberration_symbol comment);
   @XML::Complementation::ElementList = qw();
   @XML::Complementation::ElementListList = qw();
}

1;
