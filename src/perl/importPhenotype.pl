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
use Stock_Record;

use File::Basename;
use Getopt::Long;

# defaults

my $file;
my $test = 0;

my $session = new Session;

GetOptions("file=s"   => \$file,
           "test!"    => \$test,
           );

$session->die("Need to supply a -file argument.") unless $file;

open(FIL,$file) or $session->die("Cannot open $file: $!");

$session->db_begin if $test;

my $ctr = 0;

# field index to column x reference
my %xref;

LINE:
while(<FIL>) {
   chomp $_;

   # skip blank lines
   next unless $_;

   if ( /Strain/ ) {
      # a header line. Let's scan it to be sure we're still happy
      my @fields = split(/\t/,$_);
      foreach my $i (0..$#fields) {
         if ( $fields[$i] =~ /^strain$/i ) {
           $xref{strain} = $i;
         } elsif ( $fields[$i] =~ /^is_multi$/i ) {
           $xref{is_multi} = $i;
         } elsif ( $fields[$i] =~ /^is_multi_comment$/i ) {
           $xref{is_multi_comment} = $i;
         } elsif ( $fields[$i] =~ /^is_homo_viable$/i ) {
           $xref{is_homo_viable} = $i;
         } elsif ( $fields[$i] =~ /^is_homo_fertile$/i ) {
           $xref{is_homo_fertile} = $i;
         } elsif ( $fields[$i] =~ /^phenotype$/i ) {
           $xref{phenotype} = $i;
         } elsif ( $fields[$i] =~ /^genome_position_comment$/i ) {
           $xref{genome_position_comment} = $i;
         } elsif ( $fields[$i] =~ /^insertion$/i ) {
           $xref{insertion} = $i;
         } elsif ( $fields[$i] =~ /^fbid$/i ) {
           $xref{fbid} = $i;
         } else {
           $session->warn("Unprocessed field: $fields[$i].");
         }
      }
      next;
   }


   # make sure we processed a header
   $session->die("No header field found.") unless exists $xref{strain};
   # this may need rework if any field other than strain is the first field.
   map {
      $session->die("This may need rework.") if ( defined($xref{$_}) && ($xref{$_} == 0) &&  ($_ ne 'strain') )
       } keys %xref;

   my @fields = split(/\t/,$_);

   unless ( new Strain($session,{-strain_name=>$fields[$xref{strain}]})->db_exists ) {
      $session->die("There is no strain named $fields[$xref{strain}].");
   }

   my $action;
   my $pheno = new Phenotype($session,{-strain_name=>$fields[$xref{strain}]});
   if ($pheno->db_exists) {
      $session->info("Using existing record for $fields[$xref{strain}].");
      $pheno->select;
      $action = 'update';
   } else {
      $session->info("Creating new record.");
      $action = 'insert';
   }

   # various checks. the is_* fields can only be 'Y', 'N', 'U',  or 'P' (or blank)
   foreach my $f ($xref{is_multi},$xref{is_homozygous_viable},$xref{is_homozygous_fertile}) {
      next unless $f;
      $session->die("Field $f is not valid: $fields[$f]") unless
          (!$fields[$f] || $fields[$f] eq 'Y' || $fields[$f] eq 'N'
                        || $fields[$f] eq 'U' || $fields[$f] eq 'P');
   }
   $pheno->is_multiple_insertion($fields[$xref{is_multi}])
                      if $xref{is_multi} && $fields[$xref{is_multi}];
   $pheno->strain_comment($fields[$xref{is_multi_comment}])
                      if $xref{is_multi_comment} && $fields[$xref{is_multi_comment}];
   $pheno->is_homozygous_viable($fields[$xref{is_homozygous_viable}])
                      if $xref{is_homozygous_viable} && $fields[$xref{is_homozygous_viable}];
   $pheno->is_homozygous_fertile($fields[$xref{is_homozygous_fertile}])
                      if $xref{is_homozygous_fertile} && $fields[$xref{is_homozygous_fertile}];
   $pheno->phenotype($fields[$xref{phenotype}])
                      if $xref{phenotype} && $fields[$xref{phenotype}];
   $pheno->phenotype_comment($fields[$xref{genome_position_comment}])
                      if $xref{genome_position_comment} && $fields[$xref{genome_position_comment}];

   $pheno->$action;

   if (exists($xref{fbid}) ) {
      my $stock = new Stock_Record($session,{-strain_name=>$fields[$xref{strain}],
                                             -fbti=>$fields[$xref{fbid}]});
      unless ( $stock->db_exists ) {
        $stock->insertion(($xref{insertion}&&$fields[$xref{insertion}])?
                          $fields[$xref{insertion}]:$fields[$xref{strain}]);
        $stock->insert;
      } else {
        $stock->select;
        $stock->insertion(($xref{insertion}&&$fields[$xref{insertion}])?
                          $fields[$xref{insertion}]:$fields[$xref{strain}]);
        $stock->update;
      }
   }

   $ctr++;
}
     
close(FIL);

$session->info("Updated $ctr records.");

$session->db_rollback if $test;

$session->exit;
exit(0);
