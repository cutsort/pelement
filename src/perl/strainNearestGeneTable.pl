#!/usr/local/bin/perl -I../modules

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
use GeneModelSet;

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
   my %disthiH;
   my %distloH;
   my %genehiH;
   my %geneloH;
   my %straddleH;
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
         $insertH{$end} = $seqA->s_insert;
         $strandH{$end} = ($seqA->p_start > $seqA->p_end)?'-':'+';
         $armH{$end} = $seqA->scaffold;
         $armH{$end} =~ s/arm_//;
         my $cyto = new Cytology($session,{scaffold=>$seqA->{scaffold},
                                    less_than=>{start=>$insertH{$end}},
                                    -seq_release=>$release,
                    greater_than_or_equal=>{stop=>$insertH{$end}}})->select_if_exists;
         $cytoH{$end} =  ($cyto && $cyto->band)?$cyto->band:'';
         last;
      }
      
      if ($armH{$end} ne 'multiple' && $insertH{$end}) {
        my $gm = new GeneModelSet($session,$armH{$end}.'.rel5',$insertH{$end}-100000,$insertH{$end}+100000);
        $gm->select;
        $disthiH{$end} = 9999999999999;
        $distloH{$end} = 9999999999999;
        foreach my $gene ($gm->as_list) {
          if ($insertH{$end} > $gene->gene_start && $insertH{$end} < $gene->gene_end) {
            if ($insertH{$end} >= $gene->exon_start && $insertH{$end} < $gene->exon_end && $straddleH{$end} !~ /exon/) {
              $straddleH{$end} = $gene->gene_name.':exon';
            } else {
              $straddleH{$end} = $gene->gene_name;
            }
          } elsif ($insertH{$end} > $gene->gene_end && $insertH{$end} - $gene->gene_end < $disthiH{$end}) {
            $genehiH{$end} = $gene->gene_name . ' strand:'. $gene->gene_strand;
            $disthiH{$end} = $insertH{$end} - $gene->gene_end;
          } elsif ($insertH{$end} < $gene->gene_start && $gene->gene_start - $insertH{$end} < $distloH{$end}) {
            $geneloH{$end} = $gene->gene_name . ' strand:'. $gene->gene_strand;
            $distloH{$end} = $gene->gene_start - $insertH{$end};
          }
        }
     }
   }
   if (!$seqS->count) {
     print OUT join("\t",($_,"NoSeqRecord"));
   } elsif ( !$nameH{5} && !$nameH{3} && $nameH{b} ) {
     print OUT join("\t",($_,$nameH{b},$armH{b},$insertH{b},$strandH{b},$cytoH{b},
                 '','','','','')),"\t";
   } elsif ( $nameH{5} || $nameH{3} || $nameH{b} ) {
     print OUT join("\t",($_,$nameH{5},$armH{5},$insertH{5},$strandH{5},$cytoH{5},
                 $nameH{3},$armH{3},$insertH{3},$strandH{3},$cytoH{3})),"\t";
   }

   foreach my $end qw(b 5 3) {
     if ($straddleH{$end}) {
       print OUT " $end inside ",$straddleH{$end} if $straddleH{$end};
     }
     print OUT " nearest left to $end ",$geneloH{$end}," at ",$distloH{$end} if $geneloH{$end};
     print OUT " nearest right to $end ",$genehiH{$end}," at ",$disthiH{$end} if $genehiH{$end};
   }
   print OUT "\n";
    
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
