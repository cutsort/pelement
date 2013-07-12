#!/usr/bin/env perl
use FindBin::libs 'base=modules';

use Session;
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
     process_old($s,$seq_name,$seq) if $seq;
     $seq = '';
     # this will prolly need to be coded for every case
     #if ( />([A-Z]+\d+[a-z]?)/ ) {
     if ( />(.*)/) {
       $seq_name = $1;
     } else {
       print "cannot process $_\n";
     }
  } else {
    $seq .= $_;
  }
}
process_old($s,$seq_name,$seq);

close(FIL);

$s->exit;


sub process_old
{
   my ($s,$seq_name,$seq) = @_;
   return unless $seq_name && $seq;

   (my $coll = $seq_name) =~ s/\d+.*//g;
   # one-shot
   $coll = 'l';
   (my $strain_name = $seq_name) =~ s/([A-Z]+\d+).*/$1/;
   # one-shot
   ($strain_name = $seq_name) =~ s/-[35]$//;
   my $strain = $s->Strain({-strain_name=>$strain_name});
   unless ($strain->db_exists) {
     $strain->collection($coll);
     $strain->status('imported');
     $strain->insert;
   }
   my $seqRecord = $s->Seq({-seq_name=>$seq_name,
                            -strain_name=>$seq_name,
                            -sequence=>$seq,
                            -insertion_pos=>1})->insert;
}
