#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  runBlast.pl run blast one a database flanking sequence

=head1 USAGE

  runBlast.pl [options] <sequence_name>

=cut

use Pelement;
use Session;
use NCBIBlastInterface;
use Blast_OptionSet;
use Blast_RunSet;
use Seq;
use Files;
use PelementDBI;
use Getopt::Long;
use strict;

my $session = new Session();

my $db = "";
my $parser = "";
my $blastOptions = "";
my $protocol = '';
# delete previous?
my $delete;
GetOptions( "blastdb=s"  => \$db,
            "parser=s"   => \$parser,
            "blastopt=s" => \$blastOptions,
            "protocol=s" => \$protocol,
            "delete!"    => \$delete,
           );


# see if there is a predefined set of option for a blast protocol

my $blastArg = {};

# first, load default blast options
my $b_Os = new Blast_OptionSet($session,{-protocol=>'default'})->select;
# protect against typos by insisting that it be a known protocol.
$session->die("Cannot load default parameters.") unless $b_Os->as_list;
foreach my $param ($b_Os->as_list) {
  $blastArg->{'-'.$param->key} = $param->value;
}

# now load any specified protocol
if( $protocol ) {
  my $b_Os = new Blast_OptionSet($session,{-protocol=>$protocol})->select;
  # protect against typos by insisting that it be a known protocol.
  $session->die("$protocol is not a known protocol.") unless $b_Os->as_list;
  foreach my $param ($b_Os->as_list) {
     $blastArg->{'-'.$param->key} = $param->value;
  }
}

# and finally any command line specific.
$blastArg->{-db} = $db if $db;
$blastArg->{-parser} = $parser if $parser;
$blastArg->{-options} = $blastOptions if $blastOptions;

my $seq = new Seq($session,{-seq_name=>$ARGV[0]})->select;

# my $blast_score;
# # if not specified, give score cutoff for both hit and hsp
# $blast_score = length($seq->sequence)>500?1000:2*length($seq->sequence);
# $session->verbose("Minimum blast score S is $blast_score.");
# $blastArg->{-options} = "-min_raw_gapped_score $blast_score ".$blastArg->{-options} 
#   unless $blastArg->{-options} =~ /-min_raw_gapped_score/;

unless ($seq->sequence) {
   $session->die("No record for sequence $ARGV[0].");
}

# do we start with a delete?
if ($delete || ($delete eq '' && $blastArg->{-delete}) ) {
   # there is probably only 1 of these.
   my $oldRun = new Blast_RunSet($session,
            {-seq_name=>$seq->seq_name, -db=>$blastArg->{-db}})->select;
   map { $session->info("Deleting previous blast run from ".$_->date);
         $_->delete } $oldRun->as_list;
}

my $fasta_file = &Files::make_temp("seqXXXXX.fasta");

$seq->to_fasta($fasta_file);

$session->at_exit(sub{unlink $fasta_file});

my $blastRun = new NCBIBlastInterface($session,$blastArg);

$session->info("About to run blast program on $fasta_file.");

$blastRun->run($seq);

$session->info("Blast completed.");

# parse and insert
$session->error("Was not able to insert the blast run") unless $blastRun->parse;

$session->exit();

exit(0);

