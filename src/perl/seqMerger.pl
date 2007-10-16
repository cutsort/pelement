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
  alignments. This test is in addition to the consistency of the overlap

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
my $test = 0;
my $release = 5;
GetOptions('use=i'     => \$use,
           'force!'    => \$force,
           'ifaligned!'=> \$ifAligned,
           'test!'     => \$test,
           "release=i" => \$release,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.

$session->db_begin;

STRAIN:
foreach my $strain (@ARGV) {

   # all the labeled insertions
   my %insertions = ();

   # all pre-existing sequence
   my %prebuilt = ();

   $session->info("Processing strain $strain.");

   # find the associated sequences
   my $seqSet = new SeqSet($session,{-strain_name=>$strain})->select;

   unless ($seqSet->as_list) {
      $session->warn("No sequence for strain $strain.");
      next STRAIN;
   }

   # scan through the seqs to see what we have in the db. Deleting preexisting
   # built sequences if asked to force an update.

   SEQ:
   foreach my $seq ($seqSet->as_list) {
      my ($seqS,$seqE,$seqQ) = $seq->parse;
      ($session->verbose("Skipping qualified end sequence.",$seq->seq_name) and next) if $seqQ; 
      if ($seqE eq '3' || $seqE eq '5') {
         # we're dealing with unqualified sequences with an end
         unless ($seq->sequence && $seq->insertion_pos) {
            $session->warn("Sequence record for ".$seq->seq_name." is missing information. Skipping.");
            next SEQ;
         }
         $insertions{$seqS} = {ends=>{},pos=>{},names=>{}} unless exists $insertions{$seqS};
         $insertions{$seqS}->{ends}{$seqE} = $seq->sequence;
         $insertions{$seqS}->{pos}{$seqE} = $seq->insertion_pos;
         $insertions{$seqS}->{names}{$seqE} = $seq->seq_name;
      } else {
         # there is a 'both' end.
         if ($force) {
            $session->info("Deleting both-end sequence for $seqS.");
            my $seqAssSet = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;
            map { $_->delete } $seqAssSet->as_list;
            $seq->delete;
         } else {
            $session->warn("A both-end sequence already exists for $seqS. Skipping.");
            $prebuilt{$seqS} = 1;
            next SEQ;
         }
      }
   }

   INSERTION:
   foreach my $insert (keys %insertions) {

      # don't try to rebuild these
      next INSERTION if $prebuilt{$insert};

      # simplify the hash derefencing
      my %ends = %{$insertions{$insert}->{ends}};
      my %pos = %{$insertions{$insert}->{pos}};
      my %names = %{$insertions{$insert}->{names}};

      unless ( exists($ends{3}) && exists($ends{5}) ) {
         $session->warn("Both 3' and 5' sequences for $insert not present.");
         next INSERTION;
      }

      # make sure there is a consistent alignment.
      if ($ifAligned) {
         my $seqAs5 = new Seq_AlignmentSet($session,{-seq_name=>$names{5},
                                                     -seq_release=>$release})->select;
         my $seqAs3 = new Seq_AlignmentSet($session,{-seq_name=>$names{3},
                                                     -seq_release=>$release})->select;
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
            $session->info("Cannot find a common insertion location for $insert.");
            next INSERTION;
         }
      }

      foreach my $end qw(3 5) {
         unless ( ($pos{$end} > 0)  && ($pos{$end} < length($ends{$end})) ) {
            $session->warn("Insertion for end $end is outside the sequence.");
            next INSERTION;
         }
      }
        
    
      # build the both-end by taking the 5' sequence first
      my $bothSeq = $ends{5};

      # and look at the overlap
      my $ctr = 0;
      foreach my $olap (0..(length($ends{3})-1)) {
         my $base3 = substr($ends{3},$olap,1);
         my $base5 = substr($ends{5},$olap+$pos{5}-$pos{3},1);
         # hop out as soon as we get to the end.
         ($bothSeq .= substr($ends{3},$olap) and last) unless $base5;
         $session->verbose("Comparing bases $base3 and $base5 at positions $olap and ".
                                       ($olap+$pos{5}-$pos{3}));
         ($session->warn("Sequences do not agree at overlap. Skipping.") and next STRAIN )
                                       unless $base3 eq $base5;
         $ctr++;
         
      }
      $session->log_level($Session::Info);

      $session->info("Built both-end sequence for $insert. Successful match on $ctr bases.");
      $session->verbose("$insert both-end sequence is $bothSeq.");

      # we already checked and know there is not a seq record for this name.
      my $seqRecord = new Seq($session,{-seq_name      =>$insert,
                                        -sequence      =>$bothSeq,
                                        -insertion_pos =>$pos{5},
                                        -strain_name   => $strain,
                                        -last_update   =>'now'});
      $seqRecord->insert;

      # create a assembly record based on all the seq_id's of the base seq's
      my $s_a = new Seq_Assembly($session,{-seq_name      => $insert,
                                           -assembly_date => 'now',
                                           -src_seq_src   => 'seq',
                                               });


      # we'll dip again into the list to find the id of the source sequences. 
      foreach my $end (keys %names) {
         $s_a->src_seq_id(new Seq($session,{-seq_name=>$names{$end}})->select->id);
         $s_a->insert;
      }

      $session->info("Sequence record for $insert inserted.");

   }

}

if ($test) {
   $session->db_rollback;
} else {
   $session->db_commit;
}

$session->exit();

exit(0);
