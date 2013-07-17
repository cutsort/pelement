#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  gelMaster.pl do the full processing on a gel

=head1 USAGE

  gelMaster.pl gel_1 ...

=cut

use Pelement;
use Session;
use PCommon;
use Getopt::Long;
use strict;

my $session = new Session();

my $report;   # report needed work
GetOptions( "report!"      => \$report,
           );


while (@ARGV) {
  my $gel_name = shift @ARGV;
  $session->info("Looking at gel $gel_name.");
  my $gel = $session->Gel({-name=>$gel_name});
  ($session->warn("Cannot find a gel named $gel_name.") and next) unless $gel->db_exists;
  $gel->select;
  (my $batch_id = $gel->ipcr_name) =~ s/\..*//;
  my $batch = $session->Batch({-id=>$batch_id});
  ($session->warn("Cannot find a batch for $gel_name.") and next) unless $batch->db_exists;
  $batch->select;
  ($session->warn("Cannot find a type field for batch $batch_id.") and next) unless $batch->type;

  if ($batch->type eq 'New' || $batch->type eq 'Redo') {
    $session->info("Processing $gel_name as ".$batch->type." data.");
    next if $report;
    $session->verbose(shell("./baseCaller.pl -gel ".$gel_name));
    $session->verbose(shell("./seqTrimmer.pl -gel ".$gel_name));
    $session->verbose(shell("./seqImporter.pl -gel ".$gel_name));
  } elsif ($batch->type eq 'Recheck') {
    $session->info("Processing $gel_name as Recheck data.");
    next if $report;
    $session->verbose(shell("./baseCaller.pl -gel ".$gel_name));
    $session->verbose(shell("./seqTrimmer.pl -gel ".$gel_name));
    $session->verbose(shell("./buildConsensus.pl -gel ".$gel_name));
    $session->verbose(shell("./seqImporter.pl -recheck -gel ".$gel_name));
  } else {
    $session->warn("Do not know how to process $gel_name.");
    next if $report;
  }
}
  

$session->exit();

exit(0);

