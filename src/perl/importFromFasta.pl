#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

use Session;
use Gel;
use Lane;
use Phred_Seq;
use Files;
use File::Basename;

my $gel;
my $lane;
my $seq_name;
my $seq;
my $end;


my $s = new Session();

my $file = $ARGV[0];

$s->die("No such file $file.") unless -e $file;

open(FIL,$file) or $s->die("Some trouble opening file $file: $!");

while (<FIL>) {

  chomp $_;

  if ($_ =~ /^>/) {
     process_old($s,$file,$gel,$lane,$seq_name,$end,$seq) if $seq;
     $seq = '';
     if ( />([A-Z]+\d+)\.(\d+)\s+\S+\s+(\S+)\s([35]?)/ ) {
       $gel = $1;
       $lane = $2;
       $seq_name = $3;
       $end = $4;
     } else {
       print "cannot process $_\n";
     }
  } else {
    $seq .= $_;
  }
}
process_old($s,$file,$gel,$lane,$seq_name,$end,$seq);

close(FIL);

$s->exit;



sub process_old
{
   my ($s,$file,$gel,$lane,$seq_name,$end,$seq) = @_;

   my $filename = basename($file);
   my $g = new Gel($s,{-name=>$gel})->select;

   $s->die("no such gel") unless $g->id;

   my $l = new Lane($s,{gel_id=>$g->id});
   $l->seq_name($seq_name);
   $l->well($lane) if $lane;
   $l->directory("Exelixis/imported/");   # remember to change this as needed
   $l->file($filename);
   $l->end_sequenced($end) if $end;
   $l->failure('f');
   $l->insert;
   my $p = new Phred_Seq($s,{-lane_id=>$l->id});
   $p->seq($seq);
   $p->insert;
}
