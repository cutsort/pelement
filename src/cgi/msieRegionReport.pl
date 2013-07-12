#!/usr/bin/env perl
use FindBin::libs 'base=modules';

=head1 NAME

  msieRegionReport.pl Web report of insertions/genes in a region

  This is an older version of regionReport.pl which does not use
  data: URI's. We require a round trip and 2 image calc's which
  slows this one down. It does run with MS IE.

 

=cut


use Pelement;
use Session;
use PelementCGI;

use CGI::FormBuilder;
use CGI::Ajax;
use strict;

use RegionImage;

our $cgi = new PelementCGI;

my $ajax = new CGI::Ajax('move',\&imageMove);

print $ajax->build_html($cgi,\&MakeHTML);

exit(0);

sub MakeHTML 
{
  my $html;

  my $form = new CGI::FormBuilder( header=>0,
                                   method=>'GET');

  $form->field(name=>'scaffold',type=>'text',width=>20);
  $form->field(name=>'center',type=>'text',width=>20);
  $form->field(name=>'range',type=>'text',width=>20);
  $form->field(name=>'release',type=>'text',width=>20);
  $form->field(name=>'format',type=>'hidden');

  $html .= $cgi->init_page({-title=>'BDGP Pelement Region Report',
                             -style=>{-src=>'/pelement/pelement.css'}}).join('',$cgi->banner)."\n";

  if ($form->param('scaffold') && $form->param('center') && $form->param('release') ) {
    $html .= reportRegion($cgi,$form);
  } else {
    $html.= $cgi->center($form->render(submit=>['Enter']));
  }
  $html .= join('',$cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                   {link=>"setReport.pl",name=>"Set Report"},
                    ])).$cgi->close_page;

  return $html;

}

=head1 reportRegion

  Determine the insertions/genes of a region

=cut
sub reportRegion
{
  my $cgi = shift;
  my $form = shift;

  my $return;

  my $scaffold = $form->param('scaffold');
  my $center = $form->param('center');
  my $range = $form->param('range') || 10000;
  my $rel = $form->param('release') || 3;

  map { $scaffold = 'arm_'.$scaffold if $scaffold eq $_ } (qw( 2L 2R 3L 3R 4 X));

  my $session = new Session({-log_level=>0});

  my $panel = RegionImage::makePanel($scaffold,$center,$range,$rel);
  my $map = '<map name="themap">';
  map { $map .= '<area coords="'.$_->[1].','.$_->[2].','.$_->[3].','.$_->[4].
             '" href="strainReport.pl?strain='.$_->[0]->display_name.'" />'."\n"
              if ref($_->[0]) eq 'Bio::SeqFeature::Generic' } $panel->boxes;
  $map .= "</map>";

  # and make a space for the image after a navigation bar.
  $return = $cgi->center(
                 $cgi->div({-id=>'location'},
           "Release $rel Scaffold $scaffold centered at $center, range $range").
                  $cgi->br.
                  $cgi->table({-border=>0},$cgi->Tr( $cgi->td(
         [ $cgi->center($cgi->div({-id=>'downImage'},'Scroll'.$cgi->br.'Down').
                          $cgi->img({-src=>'/pelement/images/left_arrow.png',
    -onClick=>"move(['downImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Scroll Down'})),
           $cgi->center($cgi->div({-id=>'inImage'},'Zoom'.$cgi->br.'In').
                          $cgi->img({-src=>'/pelement/images/zoom_in.png',
    -onClick=>"move(['inImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Zoom In'})),
           $cgi->center($cgi->div({-id=>'outImage'},'Zoom'.$cgi->br.'Out').
                          $cgi->img({-src=>'/pelement/images/zoom_out.png',
    -onClick=>"move(['outImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Zoom Out'})),
           $cgi->center($cgi->div({-id=>'upImage'},'Scroll'.$cgi->br.'Up').
                          $cgi->img({-src=>'/pelement/images/right_arrow.png',
    -onClick=>"move(['upImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Scroll Up'})) ] )) ).$cgi->br.
                       $cgi->div({-id=>'action'},'Click to Scroll/Zoom').
                  $cgi->div({-id=>'regionImage'},
                  $cgi->a(
           $cgi->img({-width=>800,-ismap=>'t',-usemap=>'themap',-border=>'0',
              -src=>"regionImage.pl?scaffold=$scaffold&center=$center".
                                "&range=$range&release=$rel"})),$map));
  $session->exit;
  return $return;
}

=head1 imageMove

  perl code invoked by javascript for ajax.

=cut
sub imageMove {

  my $operation = shift;
  my $location = shift;

  if ($location =~ /Release\s+(\d+)\s+Scaffold\s+(\S+)\s+centered at\s+(\d+),\s+range\s+(\d+)/ ) {
    my $rel = $1;
    my $scaff = $2;
    my $center = $3;
    my $range = $4;
    if ($operation =~ /down/i) {
      $center -= int(.5+$range/2);
    } elsif ($operation =~ /up/i) {
      $center += int(.5+$range/2);
    } elsif ($operation =~ /in/i) {
      $range = int(.5+$range/2);
    } elsif ($operation =~ /out/i) {
      $range *= 2;
    }

    my $panel = RegionImage::makePanel($scaff,$center,$range,$rel);
    my $map = '<map name="themap">';
    map { $map .= '<area coords="'.$_->[1].','.$_->[2].','.$_->[3].','.$_->[4].
                           '" href="strainReport.pl?strain='.$_->[0]->display_name.'" />'."\n"
              if ref($_->[0]) eq 'Bio::SeqFeature::Generic' } $panel->boxes;
    $map .= "</map>";

    return ($cgi->a(
                $cgi->img({-width=>800,-ismap=>'t',-usemap=>'themap',-border=>'0',
                           -src=>"regionImage.pl?scaffold=$scaff&center=$center&range=$range&release=$rel"})).$map,
            "Release $rel Scaffold $scaff centered at $center, range $range");
  }
}
