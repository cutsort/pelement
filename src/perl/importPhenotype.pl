#!/usr/local/bin/perl -w -I../modules

=head1 NAME

   importPhenotye.pl

   Process the file to insert phenotype info into the db.
   This assumes a tab delimited format used by bob Levis

=cut

use Pelement;
use PCommon;
use Files;
use Session;
use Strain;
use Phenotype;

use File::Basename;
use Getopt::Long;

# defaults

my $verbose = 0;
my $file;
my $test = 0;
GetOptions("file=s"   => \$file,
           "test!"    => \$test,
           "verbose!" => \$verbose);

my $session = new Session;

$session->log_level($Session::Verbose) if $verbose;

$session->die("Need to supply a -file argument.") unless $file;

open(FIL,$file) or $session->die("Cannot open $file: $!");

my $ctr = 0;

LINE:
while(<FIL>) {
   chomp $_;

   # skip headers and blank lines
   next unless $_;
   if ( /^Strain/ ) {
      # a header line. Let's scan it to be sure we're still happy
      my @fields = split(/\t/,$_);
      if ( $fields[0] !~ /^strain$/i ||
           $fields[1] !~ /^is_multi$/i ||
           $fields[2] !~ /^is_multi_comment$/i ||
           $fields[3] !~ /^is_homo_viable$/i || 
           $fields[4] !~ /^is_homo_fertile$/i || 
           $fields[5] !~ /^phenotype$/i || 
           $fields[6] !~ /^genome_position_comment$/i ) {
         $session->die("Change in file format?");
      }
      next;
   }
   my @fields = split(/\t/,$_);

   $session->die("Cannot parse the line: $_") unless scalar(@fields) < 8;

   unless ( new Strain($session,{-strain_name=>$fields[0]})->db_exists ) {
      $session->die("There is no strain named $fields[0].");
   }

   my $action;
   my $pheno = new Phenotype($session,{-strain_name=>$fields[0]});
   if ($pheno->db_exists) {
      $session->info("Using existing record for $fields[0].");
      $pheno->select;
      $action = 'update';
   } else {
      $session->info("Creating new record.");
      $action = 'insert';
   }

   # various checks. the is_* fields can only be 'Y', 'N', 'U',  or 'P' (or blank)
   foreach my $f (1,3,4) {
      $session->die("Field $f is not valid: $fields[$f]") unless
          (!$fields[$f] || $fields[$f] eq 'Y' || $fields[$f] eq 'N'
                        || $fields[$f] eq 'U' || $fields[$f] eq 'P');
   }
   $pheno->is_multiple_insertion($fields[1]) if $fields[1];
   $pheno->strain_comment($fields[2]) if $fields[2];
   $pheno->is_homozygous_viable($fields[3]) if $fields[3];
   $pheno->is_homozygous_fertile($fields[4]) if $fields[4];
   $pheno->phenotype($fields[5]) if $fields[5];
   $pheno->phenotype_comment($fields[6]) if $fields[6];

   $pheno->$action unless $test;

   $ctr++;
}
     
close(FIL);

$session->info("Updated $ctr records.");

$session->exit;
exit(0);
