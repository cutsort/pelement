#!/usr/local/bin/perl -I../modules

=head1 NAME

  generateGenBankMail.pl process database records of imported sequences
  to create a file for submitting into to GenBank

=head1 USAGE

  generateGenBankMail.pl [options] <strain_name> [<strain_name2> ...]

=head1 Options

=item  -out <file>

  Create a new mail file.

=item  -append <file>

  Append info to an existing mail file. If <file> does not exist, it will be
  created

  The output goes to stdout if neither -out or -append is specified.
  Giving -out <file1> -append <file2> is equivalent to -append <file2>

=cut

use Pelement;
use PCommon;
use Session;
use Strain;
use PelementDBI;
use Seq_Alignment;
use Seq;
use SeqSet;
use GenBank_Submission_Info;
use Submitted_Seq;

use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();

my $outFile;
my $appendFile;
my $minLength = 25;
# only submit aligned strains?
my $ifAligned = 1;
# if no joint sequence, individual flanks?
my $subseq = 1;
GetOptions('out=s'      => \$outFile,
           'append=s'   => \$appendFile,
           'min=i'      => \$minLength,
           'ifaligned!' => \$ifAligned,
           'subseq!'    => \$subseq
          );

if ($appendFile && -e $appendFile) {
   unless (open(FIL,">> $appendFile") ) {
      $session->die("Cannot append to file $appendFile: $!");
   }
} elsif ($appendFile) {
   $session->warn("Creating new file $appendFile for appending.");
   unless (open(FIL,"> $appendFile") ) {
      $session->die("Cannot open file $appendFile for writing: $!");
   }
} elsif ($outFile) {
   unless (open(FIL,"> $outFile") ) {
      $session->die("Cannot open file $outFile for writing: $!");
   }
} else {
   *FIL = *STDOUT;
}


ARG:
foreach my $arg (@ARGV) {

   # both end seqs
   my %ends = ();
   # both insertion positions
   my %pos = ();

   $session->log($Session::Info,"Processing $arg.");

   my ($strain,$end,$qual) = Seq::parse($arg);

   # make sure this is a known sequence;
   my $st = new Strain($session,{-strain_name=>$strain});
   unless ($st->db_exists) {
      $session->warn("Strain $strain is not in the db.");
      next ARG;
   }
   $st->select;

   # don't submit these until we know how we're dealing with these.
   if ($qual) {
      $session->warn("We are not submitting qualified sequence to genbank yet.");
      next ARG;
   }

   # we handle the cases of a specified end differently from only
   # a strain designator

   if ($end && $end ne 'b') {
      my $seq = new Seq($session,{-seq_name=>$arg});
      unless ($seq->db_exists) {
         $session->warn("Sequence $arg is not in the db.");
         next ARG;
      }
      $seq->select;
      if ($ifAligned) {
         # see if there is an alignment
         my $sA_curated = new Seq_Alignment($session,{-seq_name=>$seq->seq_name,status=>'curated'});
         my $sA_unique = new Seq_Alignment($session,{-seq_name=>$seq->seq_name,status=>'unique'});
         ($session->warn("No alignments for $arg. Skipping.") and next ARG) unless 
                          $sA_curated->db_exists || $sA_unique->db_exists;
      }
      $ends{$end} = $seq->sequence;
      $pos{$end} = $seq->insertion_pos;
      
   } elsif ($subseq) {
      # find the associated sequences
      my $seqSet = new SeqSet($session,{-strain_name=>$st->strain_name})->select;

      unless ($seqSet->as_list) {
         $session->log($Session::Warn,"No sequence for strain ".$st->strain_name.".");
         next ARG;
      }

      # scan through the seqs to see what we can find
      # if we're forcing an update.

      SEQ:
      foreach my $seq ($seqSet->as_list) {
         my ($this_strain,$this_end,$this_qual) = $seq->parse;
         # only submit unqualified sequences.
         next if $this_qual;
         if ($ends{$this_end}) {
            $session->warn("This cannot deal with multiple insertions yet. Skipping.");
            next SEQ;
         }
         unless ($seq->sequence && $seq->insertion_pos) {
            $session->warn("Sequence record for ".$seq->seq_name." is missing information. Skipping.");
            next SEQ;
         }
         if ($ifAligned && ($this_end eq '3' || $this_end eq '5')) {
            # see if there is an alignment. We only check that 3' or 5' flanks are aligned.
            my $sA_curated = new Seq_Alignment($session,{-seq_name=>$seq->seq_name,status=>'curated'});
            my $sA_unique = new Seq_Alignment($session,{-seq_name=>$seq->seq_name,status=>'unique'});
           ($session->warn("No alignments for ".$seq->seq_name.". Skipping.") and next SEQ) unless 
                            $sA_curated->db_exists || $sA_unique->db_exists;
         }
         $ends{$this_end} = $seq->sequence;
         $pos{$this_end} = $seq->insertion_pos;
      }
   }

   if (exists($ends{b}) && length($ends{b}) >= $minLength ) {
      # if we have a 'both' end, we're submitting that.

      # if we're requiring alignment, then we need to see that at least 1 flanking seq has
      # an alignment
      if ($ifAligned) {
         ($session->warn("No alignments for either end of $arg. Skipping") and next) unless
                 exists($ends{5}) || exists($ends{3});
      }
      my $gb = new GenBank_Submission_Info($session,{-collection=>$st->collection})->select;
      $gb->gss($st->strain_name);
      # was this submitted before?
      $gb->status('Update') if (new Submitted_Seq($session,{-seq_name=>$st->strain_name.'-'.$end})->db_exists);

      $gb->dbxref($st->strain_name);
      $gb->add_seq('b',$ends{b},$pos{b});
      my $p_end = $gb->p_end;
      $p_end =~ s/<ENDDESCR>/Both 5' and 3' ends/;
      $gb->p_end($p_end);
      print FIL $gb->print ,"\n";
   } else {
      # otherwise, both ends are separate submissions
      foreach my $end qw(3 5) {
         if ( exists($ends{$end}) && length($ends{$end}) >= $minLength ) {
            my $gb = new GenBank_Submission_Info($session,{-collection=>$st->collection})->select;
            $gb->gss($st->strain_name.'-'.$end.'prime');

            # was this submitted before?
            $gb->status('Update') if (new Submitted_Seq($session,{-seq_name=>$st->strain_name.'-'.$end})->db_exists);

            $gb->dbxref($st->strain_name);
            $gb->add_seq($end,$ends{$end},$pos{$end});
            my $end_txt = $end."' end";
            my $p_end = $gb->p_end;
            $p_end =~ s/<ENDDESCR>/$end_txt/;
            $gb->p_end($p_end);
            print FIL $gb->print ,"\n";
         }
      }
   }
       
   $session->log($Session::Info,"Submission info for $arg generated.");

}

close(FIL);

$session->exit();

exit(0);
