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
use Seq_Assembly;
use Seq_AssemblySet;
use Seq;
use SeqSet;
use GenBank_Submission_Info;

use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();

my $outFile;
my $appendFile;
my $minLength = 25;
GetOptions('out=s'    => \$outFile,
           'append=s' => \$appendFile,
           'min=i'    => \$minLength,
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

   # we handle the cases of an end give differently from only
   # a strain designator

   if ($end) {
      my $seq = new Seq($session,{-seq_name=>$arg});
      unless ($seq->db_exists) {
         $session->warn("Sequence $arg is not in the db.");
         next ARG;
      }
      $seq->select;
      $ends{$end} = $seq->sequence;
      $pos{$end} = $seq->insertion_pos;
   } else {
      # find the associated sequences
      my $seqSet = new SeqSet($session,{-strain_name=>$st->strain_name})->select;

      unless ($seqSet->as_list) {
         $session->log($Session::Warn,"No sequence for strain ".$st->strain_name.".");
         next ARG;
      }

      # scan through the seqs to see if there is already one in the db. delete
      # if we're forcing an update.

      foreach my $seq ($seqSet->as_list) {
         my ($this_strain,$this_end,$this_qual) = $seq->parse;
         # only submit unqualified sequenaces.
         next if $this_qual;
         if ($ends{$this_end}) {
            $session->warn("This cannot deal with multiple insertions yet. Skipping.");
            next ARG;
         }
         unless ($seq->sequence && $seq->insertion_pos) {
            $session->warn("Sequence record for ".$seq->seq_name." is missing information. Skipping.");
            next ARG;
         }
         $ends{$this_end} = $seq->sequence;
         $pos{$this_end} = $seq->insertion_pos;
      }
   }

   if (exists($ends{b}) && length($ends{b}) >= $minLength ) {
      # if we have a 'both' end, we're submitting that.
      my $gb = new GenBank_Submission_Info($session,{-collection=>$st->collection})->select;
      $gb->gss($st->strain_name);
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
