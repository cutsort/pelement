#!/usr/local/bin/perl -I../modules

=head1 NAME

  regionReport.pl Web report of insertions/genes in a region

  The web report for alignments of insertions and gene models to the
  genome 

  This version (the preferred) uses Ajax and data: URI's to simplify
  the round trips.

=cut


use Pelement;
use Session;
use PelementCGI;

use CGI::FormBuilder;
use CGI::Ajax;

use MIME::Base64::Perl;
use strict;

use RegionImage;

our $cgi = new PelementCGI;


my $ajax = new CGI::Ajax('move', 
  sub {my $r=eval {imageMove(@_)}; if ($@) {print STDERR "$@"; die "$@"} $r});

print $ajax->build_html($cgi, 
  sub {my $r=eval {MakeHTML(@_)}; if ($@) {print STDERR "$@"; die "$@"} $r});

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
  $form->field(name=>'showall',type=>'hidden');

  $html .= $cgi->init_page({-title=>'BDGP Pelement Region Report',
                            -style=>{-src=>'/pelement/pelement.css'}}).
                                 join('',$cgi->banner)."\n";

  if ($form->param('scaffold') && $form->param('center') &&
                                                  $form->param('release') ) {
    $html .= reportRegion($cgi,$form);

    if( $form->param('showall') ) {
      $html .= $cgi->center($cgi->a({-href=>'regionReport.pl?scaffold='.$form->param('scaffold').
                                                '&center='.$form->param('center').
                                               '&release='.$form->param('release').
                                               '&showall=0'},'Do Not Show All'));
    } else {
      $html .= $cgi->center($cgi->a({-href=>'regionReport.pl?scaffold='.$form->param('scaffold').
                                                '&center='.$form->param('center').
                                               '&release='.$form->param('release').
                                               '&showall=1'},'Show All'));
    }
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
  my $rel = $form->param('release') || 5;
  my $showall = $form->param('showall') || 0;

  my $panel = RegionImage::makePanel($scaffold,$center,$range,$rel,$showall);
  my @areas;
  map { push @areas,
           $cgi->Area({-shape=>'rect',
                      -coords=>$_->[1].','.$_->[2].','.$_->[3].','.$_->[4],
                       -href=>'strainReport.pl?strain='.$_->[0]->display_name})
                 if ref($_->[0]) eq 'Bio::SeqFeature::Generic' } $panel->boxes;
  my $map = $cgi->Map({-name=>'linemap'},@areas);

  my $image = encode_base64($panel->png);

  # and make a space for the image after a navigation bar.
  $return = $cgi->center(
                 $cgi->div({-id=>'location',-class=>'SectionTitle'},
           "Release $rel Scaffold $scaffold centered at $center, range $range").
                  $cgi->br.
                  $cgi->table({-border=>0},$cgi->Tr( $cgi->td(
         [ $cgi->center($cgi->div({-id=>'downImage'},'Scroll'.$cgi->br.'Down').
                          $cgi->img({-src=>'/pelement/images/left_arrow.png',
                                     -class=>'flashable',
    -onClick=>"move(['downImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Scroll Down'})),
           $cgi->center($cgi->div({-id=>'inImage'},'Zoom'.$cgi->br.'In').
                          $cgi->img({-src=>'/pelement/images/zoom_in.png',
                                     -class=>'flashable',
    -onClick=>"move(['inImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Zoom In'})),
           $cgi->center($cgi->div({-id=>'outImage'},'Zoom'.$cgi->br.'Out').
                          $cgi->img({-src=>'/pelement/images/zoom_out.png',
                                     -class=>'flashable',
    -onClick=>"move(['outImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Zoom Out'})),
           $cgi->center($cgi->div({-id=>'hugeImage'},'Zoom'.$cgi->br.'Huge').
                          $cgi->img({-src=>'/pelement/images/zoom_huge.png',
                                     -class=>'flashable',
    -onClick=>"move(['hugeImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Zoom Huge'})),
           $cgi->center($cgi->div({-id=>'upImage'},'Scroll'.$cgi->br.'Up').
                          $cgi->img({-src=>'/pelement/images/right_arrow.png',
                                     -class=>'flashable',
    -onClick=>"move(['upImage','location'],['regionImage','location'],'GET');",
                            -alt=>'Scroll Up'})) ] )) ).$cgi->br.
                       $cgi->div({-id=>'action'},'Click to Scroll/Zoom').
                  $cgi->div({-id=>'regionImage'},
                  $cgi->a(
           $cgi->img({-ismap=>'t',-usemap=>'#linemap',-border=>'0',
                      -src=>"data:image/png;base64,$image"})),$map));
  return $return;
}

=head1 imageMove

  perl code invoked by javascript for ajax.

=cut
sub imageMove {

  my $operation = shift;
  my $location = shift;

  print STERR "operation is $operation\n";
  if ($location =~
    /Release\s+(\d+)\s+Scaffold\s+(\S+)\s+centered at\s+(\d+),\s+range\s+(\d+)/
                                                                            ) {
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
    } elsif ($operation =~ /huge/i) {
      $range *= 10;
    } elsif ($operation =~ /out/i) {
      $range *= 2;
    }
    my $panel = RegionImage::makePanel($scaff,$center,$range,$rel);
    my @areas;
    map { push @areas,
             $cgi->Area({-shape=>'rect',
                         -coords=>$_->[1].','.$_->[2].','.$_->[3].','.$_->[4],
                         -href=>'strainReport.pl?strain='.$_->[0]->display_name})
                   if ref($_->[0]) eq 'Bio::SeqFeature::Generic' } $panel->boxes;
    my $map = $cgi->Map({-name=>'linemap'},@areas);

    my $image = encode_base64($panel->png);

    return ($cgi->a(
                $cgi->img({-ismap=>'t',-usemap=>'#linemap',-border=>'0',
                           -src=>"data:image/png;base64,$image"})).$map,
            "Release $rel Scaffold $scaff centered at $center, range $range");
  }
}
