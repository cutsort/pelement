package XML::LocalGene;

=head1 Name

   XML::LocalGene.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::LocalGene;
   $thing = new XML::LocalGene({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;

BEGIN {
   @XML::LocalGene::AttributeRequiredList = qw(fbgn);
   @XML::LocalGene::ElementRequiredList = qw();
   %XML::LocalGene::AttributeOptionHash = ();
   @XML::LocalGene::AttributeOptionalList = qw(fb_gene_symbol fb_transcript_symbol fbtr cg_number comment);
   @XML::LocalGene::ElementList = qw();
   @XML::LocalGene::ElementListList = qw();
}

1;
