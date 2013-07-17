#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

use Session;
use Gel;
use Lane;
use Phred_Seq;
use Phred_Qual;
use Files;
use File::Basename;

my $gel;
my $lane;
my $seq_name;
my $qual;
my $end;


my $s = new Session();

my $file = $ARGV[0];
$s->die("No such file $file.") unless -e $file;
open(FIL,$file) or $s->die("Some trouble opening file $file: $!");
                                                                                                                       
while (<FIL>) {

  chomp $_;

  if ($_ =~ /^>/) {
     process_old($s,$file,$gel,$lane,$seq_name,$end,$qual) if $qual;
     $qual = '';
     if ( />([A-Z]+\d+)\.(\d+)\s+\S+\s+(\S+)\s([35]?)/ ) {
       $gel = $1;
       $lane = $2;
       $seq_name = $3;
       $end = $4;
     } else {
       print "cannot process $_\n";
     }
  } else {
    $qual .= $_;
  }
}
process_old($s,$file,$gel,$lane,$seq_name,$end,$qual);
close(FIL);
$s->exit;



sub process_old
{
   my ($s,$file,$gel,$lane,$seq_name,$end,$qual) = @_;

   my $g = new Gel($s,{-name=>$gel})->select;

   $s->die("no such gel") unless $g->id;

   my $l = new Lane($s,{-gel_id=>$g->id,
                       -seq_name=>$seq_name});
   $l->end_sequenced($end) if $end;
   $l->well($lane) if $lane;
   $l->select_if_exists;

   unless ($l->id) {
      $s->die("sequence for $seq_name does not exist");
   }
   my $p = new Phred_Seq($s,{-lane_id=>$l->id})->select_if_exists();
   unless ($p->id) {
      $s->die("Phred sequence for $seq_name does not exist");
   }

   my $pQ = new Phred_Qual($s,{-phred_seq_id=>$p->id});
   $pQ->phred_seq_id($p->id);
   @q = split(/\s+/,$qual);
   if (scalar(@q) != length($p->seq)) {
      $s->warn("Sequence and quality mismatch for $seq_name - $end. Qual has ".
               scalar(@q)." numbers and sequence is ".length($p->seq)." bases.");
      while (scalar(@q) < length($p->seq)) {
         push @q,'0';
      }
   }

   $qual = join(' ',@q);
   $pQ->qual($qual);
   $pQ->insert;

}
