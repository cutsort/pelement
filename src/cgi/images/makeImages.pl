#!/usr/bin/env perl
use FindBin::libs 'base=modules';

use strict;
use GD;

my $imWidth = 800;
my $imHeight = 100;
my $armOff = 100;

my $im = new GD::Image(11,$imHeight);

my $red = $im->colorAllocate(255,0,0);
my $black = $im->colorAllocate(0,0,0);
my $white = $im->colorAllocate(255,255,255);

# the arrow png. 2 read arrow heads connected by a line

# these numbers are tweaked to make something perfectly symmetrical.
# Is there some weirdness in the filling algorithm in GD?
$im->fill(5,5,$white);
$im->transparent($white);

my $poly = new GD::Polygon();
$poly->addPt(-1,$imHeight-1);
$poly->addPt(11,$imHeight-1);
$poly->addPt(5,$imHeight-24);
$im->filledPolygon($poly,$red);

$poly = new GD::Polygon();
$poly->addPt(0,0);
$poly->addPt(5,20);
$poly->addPt(10,0);
$im->filledPolygon($poly,$red);
$im->line(5,0,5,$imHeight-1,$red);

open(FIL,">up.png") or die "Cannot open file: $!";
binmode FIL;
print FIL $im->png;
close FIL;


# draw X
$im = new GD::Image($imWidth,$imHeight);
$black = $im->colorAllocate(0,0,0);
$white = $im->colorAllocate(255,255,255);
my $bandStart = 0;
my @bandtics = (1, 1130546, 2085092, 3696176, 5216754,
                6141167, 6891185, 8388322, 9448582, 10718603,
                11712551, 13191882, 14604312, 15638785,
                16398547, 17015315, 17884393, 18628801,
                19617763, 21050298, 21203017);
drawChrom($im,'X',$bandStart,21780003,+1,@bandtics);

# draw 2L
$im = new GD::Image($imWidth,$imHeight);
$black = $im->colorAllocate(0,0,0);
$white = $im->colorAllocate(255,255,255);
$bandStart = 20;
@bandtics = (-30856,  1318131, 2557154, 3519537, 4530525,
             5823166, 6693584, 7451625, 8247001, 9052261,
             10015042, 10559753, 11669677, 12767001, 14111290,
             16389769, 18662458, 19625057, 20935868, 21565102, 22410433);
drawChrom($im,'2L',$bandStart,22217931,+1,@bandtics);

# draw 2R
$im = new GD::Image($imWidth,$imHeight);
$black = $im->colorAllocate(0,0,0);
$white = $im->colorAllocate(255,255,255);
$bandStart = 40;
@bandtics =  (-1398214, 1000036, 2206427, 3033840, 4046137,
              4698069, 5354428, 6592453, 7410386, 8340563,
              9453251, 10466563, 11300422, 12194270, 12954650,
             13991279, 15425677, 16802291, 17719240, 18818239,
             20468637);
drawChrom($im,'2R',$bandStart,20302755,-1,@bandtics);

# draw 3L
$im = new GD::Image($imWidth,$imHeight);
$black = $im->colorAllocate(0,0,0);
$white = $im->colorAllocate(255,255,255);
$bandStart = 60;
@bandtics = ( -323260, 1383714, 2842788, 3916238, 5885849,
              7390827, 9101489, 10907330, 12128024, 13040774,
             14776486, 15732716, 16395661, 17150675, 17657392,
             19113842, 20086722, 20838139, 21761784, 22628030,
             23760641);
drawChrom($im,'3L',$bandStart,23352213,+1,@bandtics);

# 3R
$im = new GD::Image($imWidth,$imHeight);
$black = $im->colorAllocate(0,0,0);
$white = $im->colorAllocate(255,255,255);

$bandStart = 80;

@bandtics = (-257410,6719,1188813,2451278,4209085,6027547,
             7697307,9669180,11448850,13081948,14104619,15086883,
             16620390,17870002,19326109,20197277,21921995,23248066,
             24999935,26412637,28674647);
drawChrom($im,'3R',$bandStart,27890790,-1,@bandtics);


# draw 4
$im = new GD::Image($imWidth,$imHeight);
$black = $im->colorAllocate(0,0,0);
$white = $im->colorAllocate(255,255,255);
$bandStart = 100;
@bandtics = (9362,32056,1984822);
drawChrom($im,'4',$bandStart,1237870,-1,@bandtics);

sub drawChrom
{
   my $im = shift;
   my $arm = shift;
   my $bStart = shift;
   my $numBases = shift;
   my $dododad = shift;
   my @bandtics = @_;

   $im->fill(5,5,$white);
   $im->filledRectangle($armOff,$imHeight/2-1,$imWidth-$armOff,$imHeight/2+1,$black);

   foreach my $x (@bandtics) {
     my $ix =int($armOff + ($imWidth-2*$armOff)*$x/$numBases + .5); 
     $im->line($ix,$imHeight/2,$ix,$imHeight/2+5,$black);
   }

   foreach my $i (1..$#bandtics) {
      my $ix =int($armOff + ($imWidth-2*$armOff)*(.5*($bandtics[$i-1]+$bandtics[$i])-1)/$numBases + .5); 
      $im->string(gdSmallFont,$ix-4,$imHeight/2+10,$bandStart+$i,$black);
   }
   $im->string(gdMediumBoldFont,$imWidth-$armOff/2,$imHeight/2+10,"Band",$black);

   foreach my $i (0..int($numBases/1000000)) {
     my $ix =int($armOff + ($imWidth-2*$armOff)*(1000000*$i)/$numBases + .5); 
     $im->line($ix,$imHeight/2,$ix,$imHeight/2-5,$black);
     $im->string(gdSmallFont,$ix-4,$imHeight/2-20,$i,$black);
   }
   $im->string(gdMediumBoldFont,$imWidth-$armOff/2,$imHeight/2-20,"Mb",$black);

   $im->string(gdLargeFont,$armOff/2,$imHeight/2-30,$arm,$black);
   if ($dododad == -1 ) {
      my $ix =int($armOff + ($imWidth-2*$armOff)*$bandtics[0]/$numBases + .5); 
      doDad($im,$ix-10,$ix);
   } elsif ($dododad == 1) {
      my $ix =int($armOff + ($imWidth-2*$armOff)*$bandtics[-1]/$numBases + .5); 
      doDad($im,$ix+10,$ix);
   }

   open(FIL,">$arm.png") or die "Cannot open file: $!";
   binmode FIL;
   print FIL $im->png;
   close FIL;
}
sub doDad
{
   # this encapsulates the centromere dodad
   # the circle is always at the 'start'
   my ($im,$start,$end) = @_;
   my $dir = ($start<$end)?-1:+1;
   my $mstart = ($start<$end)?$start:$end;
   my $mend = ($start<$end)?$end:$start;
   $im->filledRectangle($mstart,$imHeight/2-1,$mend,$imHeight/2+1,$black);
   $im->filledRectangle(.5*($start+$end)-2,$imHeight/2-1,.5*($start+$end)+2,$imHeight/2+1,$white);
   $im->line(.5*($start+$end)-3,$imHeight/2-1+5,.5*($start+$end)-1,$imHeight/2+1-5,$black);
   $im->line(.5*($start+$end)+1,$imHeight/2-1+5,.5*($start+$end)+3,$imHeight/2+1-5,$black);
   $im->arc($start+4*$dir,$imHeight/2,8,8,0,360,$black);
   $im->fill($start+4*$dir,$imHeight/2,$black);
}

