package XML::TE_insertion_submission;

=head1 Name

   XML::TE_insertion_submission.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::TE_insertion_submission;
   $thing = new XML::TE_insertion_submission({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::DataSource;
use XML::Line;

BEGIN {
   @XML::TE_insertion_submission::AttributeRequiredList = qw();
   @XML::TE_insertion_submission::ElementRequiredList = qw(XML::DataSource);
   %XML::TE_insertion_submission::AttributeOptionHash = ();
   @XML::TE_insertion_submission::AttributeOptionalList = qw(document_create_date document_creator);
   @XML::TE_insertion_submission::ElementList = qw(XML::DataSource);
   @XML::TE_insertion_submission::ElementListList = qw(XML::Line);

}

1;
