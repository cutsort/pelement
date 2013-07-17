#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  strainTable.pl create a tab delimited table of unique or curated sequence alignments
  for a given set of strains

=head1 USAGE

  strainTable.pl -in <filename> 


=cut

use Pelement;
use PCommon;
use Session;
use Strain;
use Seq;
use SeqSet;
use Seq_AlignmentSet;
use Seq_Alignment;
use Cytology;

use strict;
use Getopt::Long;

my $file;
my $out;
my $release = 5;

GetOptions("in=s"      => \$file,
           "out=s"     => \$out,
           "release=i" => \$release,
          );

usage() unless $file;

my $session = new Session();

unless( -e $file ) {
   $session->die("Cannot find input $file: $!");
}

open(FIL,$file) or $session->die("Cannot open file $file: $!");
open(OUT,">$out") or $session->die("Cannot open file $out: $!");

while (<FIL>) {

   chomp $_;
   s/\s+//g;

   $session->info("Processing strain $_");

   my $str = new Strain($session,{-strain_name=>$_});
   next unless $str->db_exists;
   $str->select;

   # select a set based on a SQL pattern match
   my $seqS = new SeqSet($session,{-strain_name=>$_,-like=>{seq_name=>'%-_'}})->select;
   $seqS = new SeqSet($session,{-strain_name=>$_})->select unless $seqS->count;

   $session->info("Select ".scalar($seqS->as_list)." sequences.");

   my %nameH = ();
   my %insertH = ();
   my %armH = ();
   my %strandH = ();
   my %cytoH = ();
   foreach my $seq ($seqS->as_list) {

      my ($strain,$end,$qual) = $seq->parse;

      $nameH{$end} = $seq->seq_name;
      my $seqAS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name,
                                                 -seq_release => $release})->select;
      foreach my $seqA ($seqAS->as_list) {
         if ($seqA->status eq 'multiple' && !$armH{$end}) {
           $armH{$end} = 'multiple';
         }
         next if $seqA->status eq 'deselected';
         next if $seqA->status eq 'multiple';
         next if $seqA->status eq 'hiddenunique';
         $insertH{$end} = $seqA->s_insert;
         $strandH{$end} = ($seqA->p_start > $seqA->p_end)?'+':'-';
         $armH{$end} = $seqA->scaffold;
         $armH{$end} =~ s/arm_//;
         my $cyto = new Cytology($session,{scaffold=>$seqA->{scaffold},
                                    less_than=>{start=>$insertH{$end}},
                                    -seq_release=>$release,
                    greater_than_or_equal=>{stop=>$insertH{$end}}})->select_if_exists;
         $cytoH{$end} =  ($cyto && $cyto->band)?$cyto->band:'';
         last;
      }
   }
   if (!$seqS->count) {
     print OUT join("\t",($_,"NoSeqRecord",$str->status)),"\n";
   } elsif ( !$nameH{5} && !$nameH{3} && $nameH{b} ) {
     print OUT join("\t",($_,$nameH{b},$armH{b},$insertH{b},$strandH{b},$cytoH{b},
                 '','','','','',$str->status)),"\n";
   } elsif ( $nameH{5} || $nameH{3} || $nameH{b} ) {
     print OUT join("\t",($_,$nameH{5},$armH{5},$insertH{5},$strandH{5},$cytoH{5},
                 $nameH{3},$armH{3},$insertH{3},$strandH{3},$cytoH{3},$str->status)),"\n";
   }
     
}

close(FIL);
close(OUT);

$session->exit();

exit(0);

sub usage
{
   print STDERR "Usage: $0 -in <filename>\n";
   exit(2);
}
