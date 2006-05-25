package SampleSet;

=head1 Name

   SampleSet.pm   A module for the db interface for sets of sample thingies.

=head1 Usage

   use SampleSet;
   $sampleSet = new SampleSet([options]);

=cut

use strict;
use Pelement;
use PCommon;
use DbObjectSet;

=head1 sample_sheet

  Generate the contents of a sample sheet for a set of samples. This largely
  duplicates the sample_sheet method in Gel.pm, but - since we may want to generate
  sheets for things not part of batches - there is a method here as well

=cut

sub sample_sheet 
{
  my $self = shift;
  my $gel = shift;

  # fallbacks
  my $gel_name = ($gel && $gel->name) || 'Unnamed';
  my $primer = ($gel && $gel->seq_primer) || 'Unknown';

  my $contents;

  $contents = "Container Name\tPlate ID\tDescription\t".
              "Application\tApplication Instance\tContainerType\t".
              "Owner\tOperator\tPlateSealing\tSchedulingPref\n".
              "$gel_name\t$gel_name\t$gel_name\tSequencingAnalysis\t\t96-Well\t".
              "pelement\tpelement\tSepta\t1234\n".
              "Well\tSample Name\tComment\tResults Group\t".
              "Instrument Protocol 1\tAnalysis Protocol 1\n";

  # the number in the sorter is offset by 12*ascii('a'), but that's OK
  # ord only converts the first character, so we don't have to substr
  my @samples = sort { 12*ord($a->well)+substr($a->well,1)
                       <=>
                       12*ord($b->well)+substr($b->well,1) }
                                                              $self->as_list;
  foreach my $i (0..95) {
    my $row = substr('abcdefgh',int($i/12),1);
    my $col = $i%12 + 1;
    my $well = $row.$col;
    my $padded_well = uc($row).($col<10?'0':'').$col;
    if ($samples[0] && $samples[0]->well eq $well) {
      my $sample = shift @samples;
      $contents .= "$padded_well\t${gel_name}_".$sample->strain_name."_".uc($well)."_RD\t$primer";
    } else {
      $contents .= "$padded_well\tEMPTY\tEMPTY";
    }
    $contents .= "\tP-Element\tDefault 3730BDTv3-KB-DeNovo_v5\n";
  }

  return $contents;

}

1;
