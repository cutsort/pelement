package XML::DataSource;

=head1 Name

   XML::DataSource.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::DataSource;
   $thing = new XML::DataSource({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;

BEGIN {
   @XML::DataSource::AttributeRequiredList = qw(originating_lab contact_person contact_person_email);
   @XML::DataSource::ElementRequiredList = qw();
   %XML::DataSource::AttributeOptionHash = ();
   @XML::DataSource::AttributeOptionalList = qw(project_name publication_citation FBrf comment);
   @XML::DataSource::ElementList = qw();
   @XML::DataSource::ElementListList = qw();
}


1;
