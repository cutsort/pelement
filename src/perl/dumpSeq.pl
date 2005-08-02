#!/usr/local/bin/perl -I../modules

=head1 NAME

  dumpSeq.pl create a fasta file based on an SQL pattern match of seq names

=head1 USAGE

  dumpSeq.pl -file <filename> <pattern1> [<pattern2> ...]


=cut

use Pelement;
use PCommon;
use Session;
use SeqSet;
use Files;
use Submitted_Seq;

use strict;
use Getopt::Long;

my $file;

my $session = new Session();

GetOptions("file=s" => \$file
          );

usage() unless $file;


$session->warn("Removing $file.") if (-e $file );

if( -e $file && !unlink ($file)) {
   $session->die("Cannot remove $file: $!");
}

unless (Files::touch($file)) {
   $session->die("Cannot open file $file: $!");
}

while (@ARGV) {

   # process each pattern in turn.
   my $pattern = shift @ARGV;
   $session->info("Processing pattern ".$pattern);

   # select a set based on a SQL pattern match
   my $seqS = new SeqSet($session,{-like=>{seq_name=>$pattern}})->select;

   $session->info("Select ".scalar($seqS->as_list)." sequences.");

   # not the most efficient way to do this: each call is a file open and close.
   map {
      my $acc = new Submitted_Seq($session,{-seq_name=>$_->seq_name})->select_if_exists;
      $_->to_fasta(">$file",{-desc=>"[".$_->insertion_pos."]".(($acc && $acc->gb_acc)?" ".$acc->gb_acc:"")})
       } $seqS->as_list;
   
}

$session->exit();

exit(0);

sub usage
{
   print STDERR "Usage: $0  -file <filename> <pattern1> [<pattern2> ...]\n";
   exit(2);
}
