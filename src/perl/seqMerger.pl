#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqMerger.pl process database records of imported 3' and 5' sequences
  to create a consensus sequence of the joined flank.

=head1 USAGE

  seqMerger.pl [options] <strain_name> [<strain_name2> ...]

=head1 Options

=item -[no]ifaligned

  Generate a consensus if and only if there is a common insertion point for
  a sequence alignment of the 3' and 5' flank for at least one pair of
  alignments. This test is in addition to the consistenct of the overlap

=item  -force

  Force an update even if a prior sequence exists, or if there is
  disagreement in the sequence.

  If -force and -ifaligned is specified and there is not a consistent
  alignment of the flanking sequences, any existing merged sequence is
  deleted from the db.

=item  -use [3|5]

  If there is an inconsistency in the overlap, go with the specified end.

=cut

use Pelement;
use PCommon;
use Session;
use Strain;
use PelementDBI;
use Seq_Assembly;
use Seq_AssemblySet;
use Seq_Alignment;
use Seq_AlignmentSet;
use Seq;
use SeqSet;

use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();

my $force = 0;
my $use = 3;
my $ifAligned = 1;
GetOptions('use=i'     => \$use,
           'force!'    => \$force,
           'ifaligned' => \$ifAligned,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.


STRAIN:
foreach my $strain (@ARGV) {

   # both end seqs
   my %ends = ();
   # both insertion positions
   my %pos = ();
   # and their reference names
   my %names = ();

   $session->log($Session::Info,"Processing strain $strain.");

   # find the associated sequences
   my $seqSet = new SeqSet($session,{-strain_name=>$strain})->select;

   unless ($seqSet->as_list) {
      $session->log($Session::Warn,"No sequence for strain $strain.");
      next STRAIN;
   }

   # scan through the seqs to see if there is already one in the db. delete
   # if we're forcing an update.

   foreach my $seq ($seqSet->as_list) {
      if ($seq->seq_name =~ /-([35])/ ) {
         my $end = $1;
         if ($ends{$end}) {
            $session->warn("This cannot deal with multiple insertions yet. Skipping.");
            next STRAIN;
         }
         unless ($seq->sequence && $seq->insertion_pos) {
            $session->warn("Sequence record for ".$seq->seq_name." is missing information. Skipping.");
            next STRAIN;
         }
         $ends{$end} = $seq->sequence;
         $pos{$end} = $seq->insertion_pos;
         $names{$end} = $seq->seq_name;
      } else {
         # there is a 'both' end.
         if ($force) {
            $session->log($Session::Info,"Deleting both-end sequence for $strain.");
            my $seqAssSet = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;
            map { $_->delete } $seqAssSet->as_list;
            $seq->delete;
         } else {
            $session->warn("A both-end sequence already exists for $strain. Skipping.");
            next STRAIN;
         }
      }
   }

   unless ( exists($ends{3}) && exists($ends{5}) ) {
      $session->warn("Both 3' and 5' sequences for $strain not present.");
      next STRAIN;
   }

   # make sure there is a consistent alignment.
   if ($ifAligned) {
      my $seqAs5 = new Seq_AlignmentSet($session,{-seq_name=>$names{5}})->select;
      my $seqAs3 = new Seq_AlignmentSet($session,{-seq_name=>$names{3}})->select;
      my $foundCommon = 0;

      LOOKFORCOMMON:
      foreach my $s5 ($seqAs5->as_list) {
         next if $s5->status eq 'deselected';
         foreach my $s3 ($seqAs3->as_list) {
            next if $s3->status eq 'deselected';
            $foundCommon = 1 and last LOOKFORCOMMON if $s5->s_insert == $s3->s_insert;
         }
      }
      unless ($foundCommon) {
         $session->info("Cannot find a common insertion location for $strain.");
         next STRAIN;
      }
   }

   foreach my $end qw(3 5) {
      unless ( ($pos{$end} > 0)  && ($pos{$end} < length($ends{$end})) ) {
         $session->warn("Insertion for end $end is outside the sequence.");
         next STRAIN;
      }
   }
     
 
   # build the both-end by taking the 5' sequence first
   my $bothSeq = $ends{5};

   $session->log_level($Session::Debug);
   # and look at the overlap
   my $ctr = 0;
   foreach my $olap (0..(length($ends{3})-1)) {
      my $base3 = substr($ends{3},$olap,1);
      my $base5 = substr($ends{5},$olap+$pos{5}-$pos{3},1);
      # hop out as soon as we get to the end.
      ($bothSeq .= substr($ends{3},$olap) and last) unless $base5;
      $session->log($Session::Debug,"Comparing bases $base3 and $base5 at positions $olap and ".
                                    ($olap+$pos{5}-$pos{3}));
      ($session->warn("Sequences do not agree at overlap. Skipping.") and next STRAIN )
                                    unless $base3 eq $base5;
      $ctr++;
      
   }
   $session->log_level($Session::Info);

   $session->log($Session::Info,"Built both-end sequence for $strain. Successful match on $ctr bases.");
   $session->log($Session::Debug,"$strain both-end sequence is $bothSeq.");

   # we already checked and know there is not a seq record for this name.
   my $seqRecord = new Seq($session,{-seq_name      =>$strain,
                                     -sequence      =>$bothSeq,
                                     -insertion_pos =>$pos{5},
                                     -strain_name   => $strain,
                                     -last_update   =>'today'});
   $seqRecord->insert;

   # create a assembly record based on all the seq_id's of the base seq's
   my $s_a = new Seq_Assembly($session,{-seq_name      => $strain,
                                        -assembly_date => 'today',
                                        -src_seq_src   => 'seq',
                                            });
   map { $s_a->src_seq_id($_->id); $s_a->insert } $seqSet->as_list;

   $session->log($Session::Info,"Sequence record for $strain inserted.");

}

$session->exit();

exit(0);
