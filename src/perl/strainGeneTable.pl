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
   my %geneHash;
   my %nearHash;
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
        my $down = $strandH{$end}==1?0:500;
        my $up = $strandH{$end}==1?500:0;
        my $gm = new GeneModelSet($session,$armH{$end}.'.rel5',$insertH{$end}-$down,$insertH{$end}+$up);
        $gm->select if $release == 5;
        my %gene_name_hash;
        foreach my $annot ($gm->as_list) {
          # we need to see if we're really within the gene or nearby
          if( $insertH{$end} <= $annot->gene_end && $insertH{$end} >= $annot->gene_start) {
             $gene_name_hash{$annot->gene_name.'('.$annot->gene_uniquename.')'} = 'in';
          } elsif ( !exists( $gene_name_hash{$annot->gene_name.'('.$annot->gene_uniquename.')'}) ) {
             $gene_name_hash{$annot->gene_name.'('.$annot->gene_uniquename.')'} = 'near';
          }

        }
        map { push @{$geneHash{$end}}, $_ if $gene_name_hash{$_} eq 'in';
              push @{$nearHash{$end}}, $_ if $gene_name_hash{$_} eq 'near';
            } sort keys %gene_name_hash;
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

   # for the generic case, try to combine
   if (exists($geneHash{5}) && exists($geneHash{3}) &&
          join(' ',sort(@{$geneHash{3}})) eq join(' ',sort(@{$geneHash{5}}))) {
     $geneHash{b} = delete($geneHash{5});
     delete($geneHash{3});
   }
   if (exists($nearHash{5}) && exists($nearHash{3}) &&
          join(' ',sort(@{$nearHash{3}})) eq join(' ',sort(@{$nearHash{5}}))) {
     $nearHash{b} = delete($nearHash{5});
     delete($nearHash{3});
   }
     
   foreach my $end (qw(b 5 3)) {
     print OUT "\t$end within: ",join(' ',@{$geneHash{$end}}) if $geneHash{$end};
     print OUT "\t$end near: ",join(' ',@{$nearHash{$end}}) if $nearHash{$end};
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
