package Gel;

=head1 Name

   Gel.pm A module for the encapsulation of gel processing information

=head1 Usage

  use Gel;
  $gel = new Gel($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use base 'DbObject';

=head1 default_dir

  Returns the name of a default directory of a gel within
  our processing rules. This is either callable as an object
  method: $gel->default_dir or as a static method: Gel::default_dir($gel_name);

  The default directory is determined by the class and number of the gel;
  PT0456 is class PT and number 456. this will be in a group PT400_499
  and named PT0456.1

=cut
sub default_dir
{
    my $self = shift;
    my $name = ref($self)?$self->name:$self;
    my $version = shift || 1;

    if ($name =~ /^([A-Z]*)(\d+)/ ) {
       my $class = $1;
       my $gel_number = $2;
       my $gel_lo = 100*int($gel_number/100);
       my $gel_hi = $gel_lo + 99;
       return $PELEMENT_TRACE.$class.$gel_lo."_".$gel_hi."/".$name.".".$version.'/';
    } else {
       return;
    }
}

=head1

  Generate the contents of a sample sheet for a gel. This is the preferred method
  for generating a sample sheet for a registered gel

=cut

sub sample_sheet 
{
  my $self = shift;

  (my $batch = $self->ipcr_name) =~ s/^(\d+)\..*/$1/;

  return unless $batch;

  my $sS = $self->{_session}->SampleSet({-batch_id=>$batch})->select;

  my $contents;

  $contents = "Container Name\tPlate ID\tDescription\t".
              "Application\tApplication Instance\tContainerType\t".
              "Owner\tOperator\tPlateSealing\tSchedulingPref\n".
              $self->name."\t".$self->name."\t".$self->name."\tSequencingAnalysis\t\t96-Well\t".
              "pelement\tpelement\tSepta\t1234\n".
              "Well\tSample Name\tComment\tResults Group\t".
              "Instrument Protocol 1\tAnalysis Protocol 1\n";

  my @samples = sort { substr($a->well,1) <=> substr($b->well,1) ||
                       substr($a->well,0,1) cmp substr($b->well,0,1)  }
                                                              $sS->as_list;
  foreach my $i (0..95) {
    my $row = substr('abcdefgh',int($i%8),1);
    my $col = int($i/8) + 1;
    my $well = $row.$col;
    my $padded_well = uc($row).($col<10?'0':'').$col;
    if ($samples[0] && $samples[0]->well eq $well) {
      my $sample = shift @samples;
      $contents .= "$padded_well\t".$self->name."_".$sample->strain_name."_".uc($well)."_RD\t".$self->seq_primer;
    } else {
      $contents .= "$padded_well\tEMPTY\tEMPTY";
    }
    $contents .= "\tP-Element\tDefault\t3730BDTv3-KB-DeNovo_v5\n";
  }

  return $contents;

}

1;
1;
