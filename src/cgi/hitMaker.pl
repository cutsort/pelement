#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  hitMaker.pl Web interface to a directed 'blaster'

=cut

use strict;

use Pelement;
use PCommon;
use Session;
use Strain;
use Seq;
use Blast_Report;
use Blast_ReportSet;
use PelementCGI;
use PelementDBI;

use GH::Sim4;

my $cgi = new PelementCGI;
my $seq_name = $cgi->param('seq');
my $arm = $cgi->param('arm');
my $center = $cgi->param('center');
my $region = $cgi->param('region');
my $rel = $cgi->param('rel') || 6;

print $cgi->header;
print $cgi->init_page({-title=>"$seq_name Hit Maker",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner;

if ($seq_name && $arm && $center && $region ) {
   alignSeq($cgi);
} elsif ($seq_name) {
   selectArm($cgi);
   # no banner here. 
   print $cgi->close_page;
   exit(0);
} else {
   selectSeq($cgi);
}

print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                    ]);
print $cgi->close_page;

exit(0);


sub selectSeq
{

  my $cgi = shift;
  
  print
    $cgi->center(
       $cgi->h3("Enter the Sequence Name:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"hitMaker.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["Sequence Name",$cgi->textfield(-name=>"seq")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Select")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form,"\n",
    ),"\n";
}


sub selectArm
{

   my $cgi = shift;
   my $session = new Session({-log_level=>0});

   my $seq = new Seq($session,{-seq_name=>$cgi->param('seq')});
   unless ( $seq->db_exists ) {
      print $cgi->center($cgi->h2('There is no sequence in the db named '.$cgi->param('seq')));
      selectSeq($cgi);
      print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                    ]);
      print $cgi->close_page;

      return;
   }

  print
    $cgi->center(
       $cgi->h3('Enter the Arm Details:'),"\n",
       $cgi->br,
       '<FORM METHOD="GET" ACTION="hitMaker.pl" NAME="entryform">',
          $cgi->hidden(-name=>'seq',-value=>$cgi->param('seq')),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>'right'},['Arm:']).
                $cgi->td({-colspan=>4,-align=>'left'},
                    $cgi->radio_group({ -name=>'arm',
                                        -values=>['X','2L','2R','3L','3R','4'],
                                        -default=>'X',
                                        -labels=>{'X'=>'X','2L'=>'2L','2R'=>'2R',
                                                  '3L'=>'3L','3R'=>'3R','4'=>'4'},
                                        -onClick=>'displayArm()',
                                                   })),
                     $cgi->radio_group({ -name=>'rel',
                                         -values=>['3','5','6'],
                                         -labels=>{'3'=>'Release 3','5'=>'Release 5','6'=>'Release 6'},
                                         -default=>'5'}),
                 $cgi->td({-align=>'right'},'Centered at:').$cgi->td({-align=>'left',-colspan=>4},
                              $cgi->input({-name=>'center',-value=>1,-size=>12,onChange=>'resetJmp()'})),

                 $cgi->td($cgi->nbsp).
                 $cgi->td($cgi->img({-alt=>'Go Way Down',
                            -src=>'/pelement/images/left2.png',-width=>30,-onClick=>'goClk(-10)'})).
                 $cgi->td($cgi->img({-alt=>'Go Down',
                            -src=>'/pelement/images/left.png',-width=>30,-onClick=>'goClk(-1)'})).
                 $cgi->td($cgi->img({-alt=>'Go Up',
                            -src=>'/pelement/images/right.png',-width=>30,-onClick=>'goClk(1)'})).
                 $cgi->td($cgi->img({-alt=>'Go Way Up',
                            -src=>'/pelement/images/right2.png',-width=>30,-onClick=>'goClk(10)'})),
                 $cgi->td({-align=>'right'},'Region size:').$cgi->td({-align=>'left',-colspan=>4},
                                            $cgi->input({-name=>'region',-value=>2000,-size=>12})),
                 $cgi->td($cgi->nbsp).
                 $cgi->td($cgi->img({-alt=>'Go Way Down',
                            -src=>'/pelement/images/left2.png',-width=>30,-onClick=>'regClk(.1)'})).
                 $cgi->td($cgi->img({-alt=>'Go Down',
                            -src=>'/pelement/images/left.png',-width=>30,-onClick=>'regClk(.5)'})).
                 $cgi->td($cgi->img({-alt=>'Go Up',
                            -src=>'/pelement/images/right.png',-width=>30,-onClick=>'regClk(2)'})).
                 $cgi->td($cgi->img({-alt=>'Go Way Up',
                            -src=>'/pelement/images/right2.png',-width=>30,-onClick=>'regClk(10)'})),
                 $cgi->td({-align=>'right'},['Strand:']).
                 $cgi->td({-colspan=>4,-align=>'left'},
                    $cgi->radio_group({ -name=>'strand',
                                        -values=>['0','1','-1'],
                                        -default=>'0',
                                        -labels=>{'0'=>'Both','1'=>'Plus','-1'=>'Minus'}})),
                 ])),
                $cgi->td({-colspan=>2,-align=>'center'},[$cgi->submit(-name=>'Align',-value=>'Preview')]),
                $cgi->td({-colspan=>2,-align=>'center'},[$cgi->submit(-name=>'Align',-value=>'Save')]),
       $cgi->end_form,"\n",
    ),"\n",
'<br><spacer type="vertical" size=100px><br>',
$cgi->img({-src=>'/pelement/images/X.png',-id=>'Arm',-width=>800,-height=>100,-style=>'position:absolute;height=100px'}),
$cgi->img({-src=>'/pelement/images/up.png',-id=>'Cursor',-width=>11,-height=>100,-style=>'position:absolute;height=100px'}),
"\n";


print <<'JAVASCRIPT'

<script language="JavaScript">

// certain sizes are coded in this script and must be coordinated with the
// chromosome sizes
var armSize = [ 21780003, 22217931, 20302755, 23352213, 27890790, 1237870,];
// and the coordinate extents of the cytology images (the range may differ)
var armMin  = [        1,   -30856, -1398214,  -323260,  -257410,    9362 ];
var armMax  = [ 22576988, 22410433, 20468637, 23760641, 28674647, 1984822 ]; 

// these numbers are used when producing the arm maps.
var imgOffset = 100;
var imgRange = 600;

// globals used by the handlers.
var activeArm = 0;                  // the currently selected arm
var jump = .00005*armSize[activeArm];  // how much we jump on a click;
var cursorDown = -1;                // currently not moving the moose.

// preload all images.
var images = new Array(6);
var imageName = ['X','2L','2R','3L','3R','4'];
for( var i=0;i<6;i++) {
   images[i] = new Image();
   images[i].src = "/pelement/images/" + imageName[i]+".png";
}

// install event handlers for the moose moves.
document.getElementById("Cursor").onmousedown = moveCursor;
document.getElementById("Cursor").onmouseup = freezeCursor;
document.getElementById("Cursor").onmousemove = updateCursor;

// make sure the cursor is properly located.

document.getElementById("Cursor").style.left=toScreen(decomma(document.entryform.center.value)) + "px";

function displayArm(whichArm) {
   // find out which button is checked
   var whichArm=0;
   for(var i=0;i<6;i++) {
     if (this.document.entryform.arm[i].checked) whichArm=i;
   }
   document.getElementById("Arm").src = images[whichArm].src;
   activeArm = whichArm;
   resetJmp();
}

// validate the center field and remove commas (if present)
function decomma(a) {
  return a.replace(/,/g,"");
}

// put commas back in the value
function recomma(a) {
  var value = "";
  var pos = 0;
  
  for( ;; ) {
    if (a <= 0 ) return value;
    if (pos > 0 && pos % 3 == 0 ) value = "," + value;
    value  = (a % 10) + value;
    a = Math.floor(a/10);
    pos++;
  }
  return value;
}
    
// a mapping of genome coordinate to pixel
function toScreen(a)
{
  return imgOffset + Math.round(imgRange*
         Math.min(1,Math.max(0,
         (a-armMin[activeArm])/(armMax[activeArm]-armMin[activeArm]))));
}
// a mapping of pixel differences to genome differences
function fromScreen(a)
{
  return Math.round((armMax[activeArm]-armMin[activeArm])*a/imgRange);
}


// goClk is activated by image button clicks. way is +1 or -1; the
// sign of jump is determined by the last click. Repeating a click
// in the same direction increases the jump amount
function goClk(hop) {
  var center = decomma(document.entryform.center.value) - 0;
  if (hop*jump > 0 ) {
    jump *= 1.1;
  } else {
    resetJmp();
    if( hop < 0) jump = -jump;
  }
  center += Math.abs(hop)*Math.round(jump);
  // center is limited by the size of the genome
  center = Math.min(armMax[activeArm],Math.max(armMin[activeArm],center));
  document.entryform.center.value = recomma(center);
  document.getElementById("Cursor").style.left=toScreen(center) + "px";

}
// regClk is activated by image button clicks. way is +1 or -1; the
// sign of jump is determined by the last click. Repeating a click
// in the same direction increases the jump amount
function regClk(hop) {
  var region = decomma(document.entryform.region.value) - 0;
  region *= hop;
  // region is limited by the size of the genome
  region = Math.min(armSize[activeArm],Math.max(10,Math.round(region)));
  document.entryform.region.value = recomma(region);

}
function resetJmp() {
   jump = .00005*armSize[activeArm];
}

// moose events. moveCursor is called when the moose button is depressed and
// marks the cursor active.
function moveCursor(e) {
  var pos = e.screenX;
  cursorDown = pos;
}
function freezeCursor(e) {
  var pos = e.screenX;
  if (cursorDown > 0 ) {
    var center=decomma(document.entryform.center.value) - 0;
    center += fromScreen(pos - cursorDown);
    center = Math.min(armMax[activeArm],Math.max(armMin[activeArm],center));
    document.entryform.center.value = recomma(center);
    document.getElementById("Cursor").style.left=toScreen(center) + "px";
    cursorDown = -1;
  }
}
function updateCursor(e) {
  if (cursorDown > 0 ) {
    var pos = e.screenX;
    var center=decomma(document.entryform.center.value) - 0;
    center += fromScreen(pos - cursorDown);
    center = Math.min(armMax[activeArm],Math.max(armMin[activeArm],center));
    document.entryform.center.value = recomma(center);
    document.getElementById("Cursor").style.left=toScreen(center) + "px";
    cursorDown = pos;
  }
}
</script>

JAVASCRIPT
}

sub alignSeq
{
   my $cgi = shift;
    
   my $session = shift || new Session({-log_level=>0});

   my $seq = new Seq($session,{-seq_name=>$cgi->param('seq')});
   unless ($seq->db_exists) {
      print $cgi->center($cgi->h2("No record for sequence named ".$seq->seq_name));
      return;
   }

   $seq->select;

   my $center = $cgi->param('center');
   my $region = $cgi->param('region');
   $center =~ s/,//g;
   $region =~ s/,//g;
   unless ( $center =~ /^\d+$/ && $region =~ /^\d+$/ ) {
      print  $cgi->center($cgi->h2("There is some problem with the coordinates $center or $region."));
      return;
   }

   my $start = int($center - $region/2);
   my $end = int($center + $region/2 + .5);
   my $arm = $cgi->param('arm');
   # particular to genomic
   $arm = 'arm_'.$arm
     if $rel <= 5
       && ($arm eq '2L' || $arm eq '2R' || $arm eq '3L' || $arm eq '3R' || $arm eq 'X' || $arm eq '4');

   my $strand = $cgi->param('strand');
   $strand = 0 unless $strand eq '1' || $strand eq '-1';

   my $armSeq = seq_extract('/data/pelement/blast/release'.$rel.'_genomic',$arm,$start,$end);
   #print "arm sequence is $armSeq.<br>";
   #print "<BR>\n";
   #print "flank is ",$seq->sequence,"<BR>\n";
 
   unless ($armSeq) {
      print  $cgi->center($cgi->h2("There is some problem extracting sequence from $arm from $start to $end."));
      return;
   }

   my $r;
   
   $r = GH::Sim4::sim4($armSeq,$seq->sequence,{A=>1,R=>($strand==0?2:($strand==-1?1:0))});

   # debug
   #$armSeq =~ s/(.{50})/$1<br>/g;
   #my $ss = $seq->sequence;
   #$ss =~ s/(.{50})/$1<br>/g;
   #print "aligning $armSeq<br> to <br>$ss<BR>";

   if ($r->{exon_count} == 0) {
      print $cgi->center($cgi->h3("Cannot align these sequences."));
   } else {

      # we make a Blast_ReportSet to bundle enerything in 1 run
      my $brS = new Blast_ReportSet($session);

      # make a blast report object for each sim4 exon
      foreach my $i (0..($r->{exon_count}-1)) {

         my $bR = new Blast_Report($session);
         my $exon = $r->{exons}[$i];

         $bR->db('release'.$rel.'_genomic');
         $bR->seq_name($seq->seq_name);
         $bR->name($arm);

         $bR->subject_begin($start + $exon->{from1});
         $bR->subject_end($start + $exon->{to1});
         if ($r->{match_orientation} eq 'forward') {
            $bR->strand(1);
            $bR->query_begin($exon->{from2});
            $bR->query_end($exon->{to2});
         } elsif ($r->{match_orientation} eq 'reverse') {
            $bR->strand(-1);
            $bR->query_begin(length($seq->sequence) +1 - $exon->{from2});
            $bR->query_end(length($seq->sequence) + 1 - $exon->{to2});
         } else {
            print $cgi->center($cgi->h3("Serious internal problem parsing sim4 results."));
            return;
         }

         $bR->percent($exon->{match});
         $bR->match($exon->{nmatches});
         $bR->length($exon->{length});
         # this is the M=+5, N=-4 scoring scheme
         $bR->score(9*$exon->{nmatches} - 4*$exon->{length});
         
         $bR->bits(0);
         $bR->query_gaps(0);
         $bR->subject_gaps(0);
         $bR->p_val(0.);

         my @aStr = split(/\n/,$r->{exon_alignment_strings}[$i]);
         $bR->subject_align($aStr[0]);
         $bR->match_align($aStr[1]);
         $bR->query_align($aStr[2]);

         print $bR->to_html($cgi,1);
         $brS->add($bR);
      }

     if ($cgi->param('Align') eq 'Save' ) {
        print $cgi->center("Inserting record into db."),"\n";
        $brS->insert({-program=>'sim4'});
     } else {
        print $cgi->start_form(),
              $cgi->center("These results are not saved. Click the ",
              $cgi->hidden(-name=>'seq',-value=>$cgi->param('seq')),"\n",
              $cgi->hidden(-name=>'arm',-value=>$cgi->param('arm')),"\n",
              $cgi->hidden(-name=>'center',-value=>$cgi->param('center')),"\n",
              $cgi->hidden(-name=>'region',-value=>$cgi->param('region')),"\n",
              $cgi->hidden(-name=>'strand',-value=>$cgi->param('strand')),"\n",
              $cgi->hidden(-name=>'rel',-value=>($cgi->param('rel')||'6')),"\n",
              $cgi->submit(-name=>'Align',-value=>'Save'),"\n",
              " button to record the results."),
              $cgi->end_form(),"\n";
      }

   }

   print $cgi->center("Return to Strain Report for \n",
           $cgi->a({-href=>"strainReport.pl?strain=".$seq->strain_name},$seq->strain_name)),"\n";

}
