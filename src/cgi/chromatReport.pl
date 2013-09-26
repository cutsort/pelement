#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  chromatReport.pl Web report of the chromat display

=cut

use Pelement;
use Session;
use WebCache;
use Lane;

use EditTrace::ABIData;
use EditTrace::SCFData;
use EditTrace::GDInterface;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;

if ($cgi->param('img')) {
   serveImage($cgi);
} else {

   print $cgi->header();
   print $cgi->init_page({-title=>"Chromat Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
   print $cgi->banner();

   if ($cgi->param('id')) {
      reportChromat($cgi);
   } else {
      selectChromat($cgi);
   }

   print $cgi->footer();
   print $cgi->close_page();
}

exit(0);

sub serveImage
{
   my $img = shift->param('img');

   return unless $img =~ /^\d+$/;
   return unless -e $PELEMENT_WEB_CACHE.$img.'.png';
   print "Content-type: image/png\n\n";

   $cmd = "cat ".$PELEMENT_WEB_CACHE.$img.'.png';
   print `$cmd`;
}


sub selectChromat
{

   my $cgi = shift;
  
   print
     $cgi->center(
       $cgi->h3("Enter the Lane id:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"chromatReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["Lane ID",$cgi->textfield(-name=>"name")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub reportChromat
{
   my $cgi = shift;

   my $session = new Session({-log_level=>0});

   my $seq;
   my $lane;
   if ($cgi->param('id') ) {
      $lane = new Lane($session,{-id=>$cgi->param('id')});
   }

   if ( !$lane->db_exists ) {
      print $cgi->center($cgi->h2("No record for Sequence with Lane id ".
                                   $seq->lane_id.".")),"\n";
      return;
   }

   $lane->select;

   # see if we have a png
   my $png;
   my $w_p = new WebCache($session,
            {-script=>'chromatReport.pl',-param=>$lane->id,-format=>'png'});
   if ( $w_p->db_exists ) {
      $w_p->select;
      $png = $w_p->id.'.png';
      unless (-e $PELEMENT_WEB_CACHE.$png) {
         # sumthin's amiss: the file disappeared.
         $png = '';
         $w_p->delete;
      }
   }
      
   unless ($png) {
      # create a new file
      my $chromat_path = $lane->directory.$lane->file;
      $chromat_path = $PELEMENT_TRACE.$chromat_path
                                        unless $chromat_path =~ /^\//;
      return unless -e $chromat_path;

      # insert the cache record to get an id
      $w_p->insert;
      
      $png = $PELEMENT_WEB_CACHE.$w_p->id.'.png';
      createPNG($chromat_path,$png);

   }

   # what do we want to display here?
   print $cgi->center($cgi->em('Sequence of '.$lane->seq_name.
                               ($lane->end_sequenced?
                                   ('-'.$lane->end_sequenced):('')).
                               ' from '.$lane->directory.$lane->file.
                               ' run on '.$lane->run_date));
                               

   print $cgi->center($cgi->img({-src=>'chromatReport.pl?img='.$w_p->id})),"\n";

   print $cgi->em(qq(Note: the base calls in the chromat are from the ABI
                     base caller and may not agree with the base calls used
                     in the sequence processing)),"\n";


   $session->exit();
}

sub createPNG
{
   my $path = shift;
   my $png = shift;

   my $data_per_line = 700;
   my $image_width = 700;
   my $panel_height = 100;
   my $char_height = 12;

   my $chromat_type = EditTrace::TraceData::chromat_type($path);
   my $chromat = new $chromat_type;
   $chromat->readFile($path);

   # $data_per_line points per $image_width pixel line
   my $nPts = $chromat->{Header}->{samples};
   my $nPanels = int(($nPts-1)/$data_per_line)+1;

   my $drawable = new EditTrace::GDInterface($image_width,$panel_height*$nPanels);

   my $bg = $drawable->{image}->colorAllocate(250,250,250);
   my $red = $drawable->{image}->colorAllocate(255,0,0);
   my $green = $drawable->{image}->colorAllocate(0,205,0);
   my $blue = $drawable->{image}->colorAllocate(0,0,255);
   my $black = $drawable->{image}->colorAllocate(0,0,0);
   $drawable->{image}->rectangle(0,0,$image_width,$panel_height*$nPanels,$bg);
   $drawable->{image}->fill(1,1,$bg);

   foreach $i (0..$nPanels-1) {
      my $lo = $data_per_line*($i);
      my $hi = $data_per_line*($i+1);
      my $xhi = $image_width;
      if ($hi > $nPts-1) {
         $xhi = $xhi - ($hi-$nPts);
         $hi = $nPts-1;
      }
      my $ytrans = $panel_height*($nPanels-1-$i);
      $drawable->{ytext} = $ytrans+$char_height;
      $drawable->{color} = $red;
      $chromat->plot($drawable,{bases=>['A'],
                                xrange=>[0,$xhi],
                                dataRangeX=>[$lo,$hi],
                        yrange=>[$ytrans+$char_height,$ytrans+$panel_height]});
      $drawable->{color} = $blue;
      $chromat->plot($drawable,{bases=>['C'],
                                xrange=>[0,$xhi],
                                dataRangeX=>[$lo,$hi],
                        yrange=>[$ytrans+$char_height,$ytrans+$panel_height]});
      $drawable->{color} = $black;
      $chromat->plot($drawable,{bases=>['G','N'],
                                xrange=>[0,$xhi],
                                dataRangeX=>[$lo,$hi],
                        yrange=>[$ytrans+$char_height,$ytrans+$panel_height]});
      $drawable->{color} = $green;
      $chromat->plot($drawable,{bases=>['T'],
                                xrange=>[0,$xhi],
                                dataRangeX=>[$lo,$hi],
                        yrange=>[$ytrans+$char_height,$ytrans+$panel_height]});
   }

   open(FIL,"> $png") or return;
   binmode FIL;
   print FIL $drawable->{image}->png;
   close(FIL);
   return 1;
}
