#!/usr/local/bin/perl -I../modules

=head1 NAME

  runBlast.pl run blast one a database flanking sequence

=head1 USAGE

  runBlast.pl [options] <sequence_name>

=cut

use Pelement;
use Session;
use BlastInterface;
use Seq;
use Files;
use PelementDBI;
use Getopt::Long;
use strict;

my $session = new Session({-log_level=>$Session::Verbose});

my $db = "";
my $parser = "";
my $blastOptions = "";
GetOptions( "db=s"       => \$db,
            "parser=s"   => \$parser,
            "blastopt=s" => \$blastOptions,
           );

my $blastArg = {};
$blastArg->{-db} = $db if $db;
$blastArg->{-parser} = $parser if $parser;
$blastArg->{-options} = $blastOptions if $blastOptions;

my $seq = new Seq($session,{-seq_name=>$ARGV[0]})->select;

my $blast_score = length($seq->sequence);

$session->log($Session::Info,"Minimum blast score is $blast_score.");

$blastArg->{-options} .= " S=$blast_score" unless $blastArg->{-options} =~ /S\s*=/;

unless ($seq->sequence) {
   $session->die("No record for sequence $ARGV[0].");
}

my $fasta_file = &Files::make_temp("seqXXXXX.fasta");

$seq->to_fasta($fasta_file);

$session->at_exit(sub{unlink $fasta_file});

my $blastRun = new BlastInterface($session,$blastArg);

$session->log($Session::Info,"About to run blast program on $fasta_file.");

$blastRun->run($seq);

$session->log($Session::Info,"Blast completed.");

my $sql = $blastRun->parse_sql();

$session->log($Session::Verbose,"SQL: $sql.");

$session->get_db->do($sql) if ($sql);

$session->exit();

exit(0);

