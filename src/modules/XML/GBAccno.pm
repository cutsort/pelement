package XML::GBAccno;

=head1 Name

   XML::GBAccno.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::GBAccno;
   $thing = new XML::GBAccno({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;

BEGIN {
   @XML::GBAccno::AttributeRequiredList = qw(accession_version);
   @XML::GBAccno::ElementRequiredList = qw();
   %XML::GBAccno::AttributeOptionHash = ();
   @XML::GBAccno::AttributeOptionalList = qw(comment);
   @XML::GBAccno::ElementList = qw();
   @XML::GBAccno::ElementListList = qw();
}

1;
