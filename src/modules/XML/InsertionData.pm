package XML::InsertionData;

=head1 Name

   XML::InsertionData.pm A module for generating XML for flybase submissions

=head1 Usage

   use XML::InsertionData;
   $thing = new XML::InsertionData({attribute=>value});
   $thing->add(new Child);

   $thing->to_xml

=cut

use XML::Base;
use XML::Complementation;
use XML::FlankSeq;
use XML::GenomePosition;
use XML::ScaffoldPosition;
use XML::WithinGene;
use XML::WithinTranscript;
use XML::WithinCDS;
use XML::AffectedGene;

BEGIN {
   @XML::InsertionData::AttributeRequiredList = qw(line_id);
   @XML::InsertionData::ElementRequiredList = qw(XML::FlankSeq);
   %XML::InsertionData::AttributeOptionHash = (is_homozygous_viable => [qw(Y)],
                                               is_homozygous_fertile => [qw(Y)],
                                               is_update => [qw(Y)]);
   @XML::InsertionData::AttributeOptionalList = qw(is_homozygous_viable is_homozygous_fertile associated_aberration phenotype derived_cytology is_update comment);
   @XML::InsertionData::ElementList = qw();
   @XML::InsertionData::ElementListList = qw(XML::Complementation XML::FlankSeq XML::GenomePosition XML::ScaffoldPosition XML::WithinGene XML::WithinTranscript XML::WithinCDS XML::AffectedGene);
}

1;
