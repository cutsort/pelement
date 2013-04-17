#!/usr/local/bin/perl -w -I../modules

=head1 NAME

   processGenBankAcc.pl

   Process the file to insert GenBank accession id's into the db.

=cut

use Pelement;
use PCommon;
use Files;
use Session;
use Seq;
use Submitted_Seq;

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
   next if /^dbGSS_Id/;
   next if /^dbEST_Id/;
   next if /^==/;

   my ($dbgss,$name,$acc) = split(/\s+/,$_);

   $session->warn("Cannot parse the line: $_") unless $dbgss && $name && $acc;

   $name =~ s/prime$//;

   unless ( new Seq($session,{-seq_name=>$name})->db_exists ) {
      $session->die("There is no sequence named $name.");
   }

   my $sseq = new Submitted_Seq($session,{-seq_name=>$name});


   # eventually, we'll make this more sophisitcated. For now, we're only
   # going to put in new records only.
   ($session->warn("Already have a db entry for $name.") and next) if $sseq->db_exists;

   # this is irrelevant for now
   if ($sseq->dbgss_id  || $sseq->gb_acc) {
      if ( $sseq->dbgss_id ne $dbgss) {
         $session->die("There is a genbank id for $name and it disagrees.");
      } elsif ( $sseq->gb_acc ne $acc) {
         $session->die("There is a genbank accession for $name and it disagrees.");
      } elsif ( $sseq->gb_acc eq $acc && $sseq->dbgss_id eq $dbgss) {
         $session->warn("There is already an accession and gss id for $name.");
         next LINE;
      }
   }

   $sseq->dbgss_id($dbgss);
   $sseq->gb_acc($acc);
   $sseq->submission_date('today');
   $sseq->insert;
   $ctr++;
}
     
close(FIL);

$session->info("Updated $ctr records.");

$session->exit;
exit(0);

