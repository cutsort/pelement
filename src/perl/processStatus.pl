#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

   processStatus.pl

   Process the file to update strain statuses in the db.

=cut

use Pelement;
use PCommon;
use Files;
use Session;
use Strain;

use File::Basename;
use Getopt::Long;

# defaults
my $file;

my $session = new Session;

GetOptions("file=s"   => \$file,
           );


$session->die("Need to supply a -file argument.") unless $file;
open(FIL,$file) or $session->die("Cannot open $file: $!");

my $ctr = 0;

LINE:
while(<FIL>) {
   chomp $_;

   # skip headers and blank lines
   next unless $_;
   next if /^Strain/i;

   my ($name,$status) = split(/\s+/,$_);

   $session->warn("Cannot parse the line: $_") unless $name && $status;

   my $strain = new Strain($session,{-strain_name=>$name});
   unless ( $strain->db_exists ) {
      $session->warn("There is no strain named $name.");
      next LINE;
   }
   $strain->select;
   $strain->status($status);
   $strain->update('strain_name');

   $ctr++;
}
     
close(FIL);

$session->info("Updated $ctr records.");

$session->exit;
exit(0);

