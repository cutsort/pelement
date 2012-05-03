#!/usr/local/bin/perl -I../modules

=head1 NAME

  regionImage.pl

=head1 DESCRIPTION 

  The guts of a region image maker. This is normally used as a back end script

=cut

use Pelement;
use strict;

use RegionImage;

use ChadoGeneModelSet;
use CGI::FormBuilder;

# graphics
use Bio::Graphics;
use Bio::SeqFeature::Generic;
use Bio::SeqFeature::Gene::Transcript;
use Bio::SeqFeature::Gene::Exon;

my $form = new CGI::FormBuilder( header=>0,
                                 method=>'GET');

$form->field(name=>'scaffold',type=>'hidden');
$form->field(name=>'center',type=>'hidden');
$form->field(name=>'range',type=>'hidden');
$form->field(name=>'format',type=>'hidden');
$form->field(name=>'release',type=>'hidden');

my $panel;
if ($form->param('scaffold') && $form->param('center') && $form->param('release') ) {
  $panel = RegionImage::makePanel($form->param('scaffold'),
                                  $form->param('center'),
                                  $form->param('range') || 5000,
                                  $form->param('release') );

  if (!$form->param('format') || $form->param('format') eq 'png') {
    print "Content-type: image/png\n\n";
    print $panel->png;
  }

}
exit(0);
