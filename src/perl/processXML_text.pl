#!/usr/local/bin/perl -w -I../modules

=head1 NAME

   processXML.pl

   Process the file to insert FlyBase id's into the db.

=cut

use Pelement;
use PCommon;
use Files;
use Session;
use Stock_Record;
use Stock_RecordSet;

use File::Basename;
use Getopt::Long;


my $session = new Session;
my $file;
GetOptions("file=s"   => \$file,
           );


$session->die("Need to supply a -file argument.") unless $file;

$session->die("$file cannot be located.") unless -e $file;


open(FIL,$file) or $session->die("Cannot open $file: $!");

while (<FIL>) {

  chomp $_;

  my ($line_id,$fbti,$insertion_symbol) = split(/\t/,$_);

  $session->verbose("$line_id has fbti $fbti and symbol $insertion_symbol.");
  my $action;
  my $stock = new Stock_Record($session,{-fbti=>$fbti});

  if ($stock->db_exists) {
    $action = 'update';
    $stock->select;
    $session->die("Fbti is recorded for another line ".$stock->strain_name.
                  " and not $line_id.") if ($stock->strain_name ne $line_id );
  } else {
    $action = 'insert';
    $stock->strain_name($line_id);
  }

  $stock->fbti($fbti);
  $stock->insertion_symbol($insertion_symbol);
  $stock->$action;
  $ctr++;
}

close(FIL);
$session->info("Updated $ctr records.");

$session->exit;

exit(0);
