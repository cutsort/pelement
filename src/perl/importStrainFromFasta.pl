#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

use Session;
use Strain;
use Files;

my $seq_name;
my $collection;

my $s = new Session();

while (<STDIN>) {

  chomp $_;

  if ($_ =~ /^>/) {
     process_old($s,$collection,$seq_name) if $collection;
     $seq = '';
     if ( />G\d+\.\d+\s+(\S+)\s+(\S+)\s[35]/ ) {
       $collection = $1;
       $seq_name = $2;
     } else {
       print "cannot process $_\n";
     }
  }
}
process_old($s,$collection,$seq_name);
$s->exit;

sub process_old
{
   my ($s,$collection,$seq_name) = @_;

   my $g = new Strain($s,{-strain_name=>$seq_name});

   if ($g->db_exists) {
      $g->select;
      if ($g->collection ne $collection) {
         $s->die("There is already a strain $seq_name with a different collection.");
      }
      return;
   }

   $g->collection($collection);
   $g->status('Exelixis');
   $g->registry_date('today');
   $g->insert;
}
