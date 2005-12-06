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

use XML::XPath;
use XML::XPath::Parser;

# defaults

my $session = new Session;
my $file;
GetOptions("file=s"   => \$file,
           );


$session->die("Need to supply a -file argument.") unless $file;

$session->die("$file cannot be located.") unless -e $file;

my $xp = XML::XPath->new(filename=>$file);
# do something if it fails


# locate all nodes.
my @nodes = $xp->find('//Insertion')->get_nodelist;
$session->info("Found ",scalar(@nodes)," insertions.");

my $ctr = 0;
foreach my $node (@nodes) {

  my $line_id = $node->getParentNode->getAttribute('line_id');
  my $fbti = $node->getAttribute('fbti');
  my $insertion_symbol = $node->getAttribute('insertion_symbol');

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

$session->info("Updated $ctr records.");

$session->exit;

exit(0);
