#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  font.pl Web test of fonts

=cut

use Pelement;
use PelementCGI;

use CGI::FormBuilder;
use CGI::Session qw/-ip-match/;

use strict;

my $cgi = new PelementCGI;

print $cgi->header;
print $cgi->init_page({-title=>"Font Test",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();

my $form = new CGI::FormBuilder(
           header => 0,
           method => 'POST',
           );


my $fonts = ['serif','monospace','sans-serif','cursive','Times','Georgia',
             'New Century Schoolbook','Geneva','Univers','Arial','Courier',
             'Times','Helvetica','Verdana','Adobe Courier'];

$form->field(name=>'font',options=>$fonts,value=>'serif');
$form->field(name=>'size',options=>[qw(5 6 7 8 9 10 11 12 14 14 15 16 17 18)], value=>10);
$form->field(name=>'units',options=>[qw(pt px mm)], value=>'pt');
$form->field(name=>'weight',options=>[qw(normal bold bolder lighter)], value=>'normal');
$form->field(name=>'slant',options=>[qw(normal oblique italic)], value=>'normal');
$form->field(name=>'color',options=>[qw(black red blue green yellow)], value=>'black');


my $font = $form->param('font');
$font = "'".$font."'" if $font =~ /\s/;
my $size = $form->param('size');
my $units = $form->param('units');
my $weight = $form->param('weight');
my $slant = $form->param('slant');
my $color = $form->param('color');

my $style = "font-family: $font;".
            "font-style: $slant;".
            "font-weight: $weight;".
            "font-size: $size$units;".
            "color: $color;";
          
print $cgi->center("Generated with style: $style.");

print $cgi->div({-style=>$style."margin-right: 10%; margin-left: 10%; text-indent: 12mm"},text($cgi)),"\n";
print $cgi->center($form->render(submit=>['Display']));

print $cgi->close_page();

exit(0);

sub text
{

  my $cgi = shift;

  return $cgi->p(qq(Lorem ipsum dolor sit amet, consectetuer adipiscing
  elit. Maecenas congue magna. Vestibulum aliquet metus at diam. Donec
  leo elit, elementum vitae, tempor in, sollicitudin laoreet, enim.
  Aliquam sem. Pellentesque interdum diam et dolor rutrum accumsan.
  Phasellus tempus. Quisque dictum fermentum turpis. Mauris volutpat.
  Integer elementum turpis ac tellus. In interdum turpis eget quam. Sed
  orci magna, consequat tempor, viverra vel, tempor nec, lectus. Mauris
  mollis condimentum augue. Suspendisse potenti. In hac habitasse
  platea dictumst. Vivamus nec ligula. Morbi nec magna et leo aliquam
  posuere. Mauris placerat est at odio.)).

  $cgi->p(qq(Maecenas in sapien et quam lacinia auctor. Sed purus.
  Mauris elit ante, lacinia molestie, malesuada vitae, rhoncus sit
  amet, ligula. Nullam et ante. Vivamus et nunc. Proin tempor urna a
  elit. Aenean viverra felis vel est. Vestibulum faucibus. Sed vel
  nibh. Pellentesque cursus est quis nunc. Cum sociis natoque penatibus
  et magnis dis parturient montes, nascetur ridiculus mus. Aliquam
  laoreet, metus vitae aliquet sagittis, turpis pede fringilla tortor,
  non gravida nibh tortor in arcu. Sed tellus. Vivamus id quam eu enim
  luctus gravida. Quisque erat pede, commodo ut, sagittis in, pretium
  fringilla, elit.)).

  $cgi->p(qq(In hac habitasse platea dictumst. Fusce mattis nisl in
  tortor. Nam non libero id risus porttitor dictum. Vestibulum
  ultrices. Duis sagittis cursus massa. Mauris dapibus neque quis
  felis. In ullamcorper augue id arcu. Fusce urna leo, sodales quis,
  malesuada molestie, aliquam sed, metus. Etiam diam. Nullam est ante,
  semper dignissim, porta et, cursus venenatis, erat. Vestibulum nulla.
  Maecenas vel sem. In vel libero et ante molestie volutpat. Donec sit
  amet metus. Donec varius odio vitae est tincidunt convallis.
  Pellentesque congue ligula vel nulla. Vestibulum et nisi. Suspendisse
  sodales dui ut leo.)).

  $cgi->p(qq(Phasellus lorem. Morbi sagittis laoreet risus. Nunc
  convallis, metus quis blandit porta, ante lectus auctor elit, in
  volutpat lectus orci sit amet magna. Lorem ipsum dolor sit amet,
  consectetuer adipiscing elit. Sed pellentesque tincidunt libero.
  Fusce consequat imperdiet neque. Nunc vitae sapien. Integer nulla
  libero, malesuada vel, semper eu, mollis nec, nisi. Nam elit orci,
  lobortis at, consectetuer vitae, porttitor nec, ante. Proin a metus
  id tellus commodo vulputate. Maecenas dui ante, facilisis sit amet,
  ornare quis, faucibus in, purus. In blandit, risus at convallis
  vehicula, ante nunc suscipit ligula, mollis pretium augue magna ut
  augue. Praesent risus diam, aliquam sit amet, pulvinar sed, molestie
  eu, enim. Suspendisse ut augue in sem fermentum dapibus. Nullam at
  urna vitae leo tempor auctor. Maecenas fringilla lacus vitae pede.
  Nam aliquam dui quis nisi. Maecenas nisl lectus, elementum non,
  laoreet eu, euismod at, felis. Cum sociis natoque penatibus et magnis
  dis parturient montes, nascetur ridiculus mus.)).

  $cgi->p(qq(Pellentesque sed dui. Aenean quis felis commodo dui
  iaculis ultricies. Etiam sapien. Cras consequat venenatis nunc.
  Curabitur quis elit quis felis euismod suscipit. Maecenas odio ipsum,
  vulputate nec, cursus a, sodales non, orci. Etiam diam. Fusce
  venenatis luctus libero. Cras tortor nunc, convallis vitae, tincidunt
  in, placerat sed, dolor. Fusce cursus, ante ac iaculis vulputate,
  eros risus faucibus leo, laoreet imperdiet lectus turpis at metus.
  Praesent a magna non purus bibendum eleifend. Suspendisse at turpis
  non quam semper rutrum. In ut lorem sed risus cursus elementum.
  Vestibulum malesuada. Integer tristique. Proin lorem. Vestibulum
  dictum, risus sed feugiat auctor, risus eros malesuada velit, eget
  dignissim enim nunc non diam. Nulla tortor. In hac habitasse platea
  dictumst. Nam quam dolor, iaculis vel, convallis vitae, condimentum
  eget, ipsum.));
}


