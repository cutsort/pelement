#!/usr/local/bin/perl -I../modules

=head1 NAME

  buildConsensus.pl process database record of phred sequence and 
  quality generate a consensus sequence from multiple trimmed sequences.

=head1 USAGE

  buildConsensus.pl <-gel name> | <-gel_id number> |  <-lane name> | <-lane_id number> | <-seq name>

  One of gel name, gel id, lane (file) name, lane id, or seq name must be specified.

=cut

use Pelement;
use PCommon;
use Collection_Protocol;
use Files;
use Gel;
use Lane;
use LaneSet;
use PelementDBI;
use PhrapInterface;
use Phred_Qual;
use Phred_Seq;
use Seq;
use Seq_Assembly;
use Seq_AssemblySet;
use Session;
use Strain;
use Trimming_Protocol;

use File::Basename;
use Getopt::Long;
use strict;

my $session = new Session();

# option processing. 
# we specify what we are processing by the switch of either
#         -gel Name         process a gel by name
#         -gel_id Number    process a gel by internal db number id
#         -lane Name        process a lane by filename
#         -lane_id Number   process a lane by internal db number id
#         -seq Name         process a seq by name
#         -force            replace an existing sequence record.
#         -test             do not update db records.

my ($gel_name,$gel_id,$lane_name,$lane_id,$process_seq,$force);

my $minSeqSize = 12;
my $maxSeqSize = 0;
my $test = 1;      # test mode only. No inserts or updates.

GetOptions('gel=s'      => \$gel_name,
           'gel_id=i'   => \$gel_id,
           'lane=s'     => \$lane_name,
           'lane_id=i'  => \$lane_id,
           'seq=s'      => \$process_seq,
           'min=i'      => \$minSeqSize,
           'max=i'      => \$maxSeqSize,
           'force!'     => \$force,
           'test!'      => \$test,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.

my ($gel,@lanes);

if ($gel_name || $gel_id) {
   unless ($gel_id) {
      $gel = new Gel($session,{-name=>$gel_name})->select_if_exists;
      $session->die("Cannot find gel with name $gel_name.") unless $gel;
      $gel_id = $gel->id;
   }
   my $laneSet = new LaneSet($session,{-gel_id=>$gel_id})->select;
   @lanes = $laneSet->as_list;
} elsif ( $lane_name ) {
   @lanes = (new Lane($session,{-file=>$lane_name})->select_if_exists);
} elsif ( $lane_id ) {
   @lanes = (new Lane($session,{-id=>$lane_id})->select_if_exists);
} elsif ( $process_seq ) {
   # we only need to pull 1 lane per end when we select by seq name; the
   # rest will come later
   my $laneSet = new LaneSet($session,{-seq_name=>$process_seq})->select;
   my %gotEnd = ();
   foreach my $l ($laneSet->as_list) {
      $l->end_sequence('unknown') unless $l->end_sequenced;
      push @lanes, $l unless $gotEnd{$l->end_sequenced};
      $gotEnd{$l->end_sequenced} = 1;
   }
} else {
   $session->die("No options specified for trimming.");
}

$session->log($Session::Info,"There are ".scalar(@lanes)." lanes to process");


LANE:
foreach my $lane (@lanes) {

   $session->log($Session::Info,"Processing lane ".$lane->seq_name);

   # and we'll need the strain and processing info.
   my $strain = new Strain($session,{-strain_name=>$lane->seq_name})->select;
   unless ($strain && $strain->collection) {
      $session->warn("No collection identifier for ".$lane->seq_name);
      next LANE;
   }

   # things that we'll need when locating the insertion.
   my $c_p = new Collection_Protocol($session,
                       {-collection=>$strain->collection,
                        -like=>{end_sequenced=>'%'.$lane->end_sequenced.'%'}}
                                                     )->select;
   unless ($c_p->protocol_id) {
      $session->warn("Cannot determine trimming protocol for ".
                                                          $strain->collection);
      next LANE;
   }

   my $t_p = new Trimming_Protocol($session,{-id=>$c_p->protocol_id})->select;
   if ($t_p->id) {
      $session->info("Using trimming protocol ".$t_p->protocol_name)
                                                          if $t_p->protocol_name;
   } else {
      $session->warn("Cannot determine trimming protocol for ".
                                                          $strain->collection);
      next LANE;
   }

   # look for all phred seq for this end and this seq
   my $laneSet = new LaneSet($session,{-seq_name=>$lane->seq_name,
                                        -end_sequenced=>$lane->end_sequenced})->select;

   my @phred_seq = ();
   # find the associated phred called sequences.
   foreach my $l ($laneSet->as_list ) {
      next LANE if PCommon::is_true($l->failure);
      push @phred_seq, new Phred_Seq($session,{-lane_id=>$l->id})->select_if_exists;
   }

   # the temporary files
   my $seqFile = &Files::make_temp("phrap".$$."_XXXXX.fa") ||
             $session->die("Cannot create temp file for sequence");
   
   my $qualFile = $seqFile.".qual";

   open(SEQ,">$seqFile") || $session->die("Cannot open file $seqFile for writing: $!");
   open(QUAL,">$qualFile") || $session->die("Cannot open file $qualFile for writing: $!");
   
   # keep records of all the phred_seq id's and whether any have been vector trimmed.
   my $foundVec = 0;
   my %pidH = ();
   foreach my $p (@phred_seq)  {
      next unless $p && $p->id;

      my $qual = new Phred_Qual($session,{-phred_seq_id=>$p->id})->select;

      my ($trimSeq,$start_flag,$end_flag) = $p->trimmed_seq;

      next unless $trimSeq;
      my $trimQual = $qual->trimmed_qual($p);

      $foundVec = 1 if $start_flag eq 'v';
      $pidH{$p->id} = 1;

      print SEQ ">",$lane->seq_name,":",$p->id,"\n";
      print SEQ $trimSeq,"\n";
      $session->info("Consensus sequence for ".$lane->seq_name.":".$p->id." is $trimSeq.");
      print QUAL ">",$lane->seq_name,":",$p->id,"\n";
      print QUAL $trimQual,"\n";
   }

   close(SEQ);
   close(QUAL);

   my $insert_pos = $foundVec?$t_p->insertion_offset:-1;

   my $phrap = new PhrapInterface($session,{-file=>$seqFile,-save=>0});
   unless ( $phrap->run ) {
      $session->warn("Some trouble running phrap.");
      next LANE;
   }

   my $nC = $phrap->contigs;
   my $nS = $phrap->singlets;

   $session->info("Returned $nC contigs and $nS singlets.");

   my @contigs = $phrap->contigs;
   # see how many seqs were kicked out.
   my %singlets = $phrap->singlets;

   # we're insisting on clean seq.
   if ($nC != 1) {
      if ($nC == 0 && $nS == 1) {
         # this is a special case: there was only 1 input sequence.
         # phrap calls this a singlet, but we call it an assembly
         @contigs = $phrap->singlets;
         %singlets = ();
      } else {
         $session->warn("Sequences did not assemble into 1 contig.");
         next LANE;
      }
   }

   # keep track of the phred_seq id's that got assembled. We need to
   # strip off some info phrap included.
   my @kickedOut = keys %singlets;

   map { s/.*:(\d+)$/$1/ } @kickedOut;
   map { delete $pidH{$_} } @kickedOut;

   $session->info("Assembly consists of reads from ".join(", ",keys %pidH));
   
   # we insist that sequences used to generate an existing read be in the revised
   # assembly

   $session->info("The sequences not assembled are @kickedOut.") if @kickedOut;
   $session->info("Consensus sequence for Contig1       is $contigs[1].");
   my $seq = uc($contigs[1]);

   my $seq_name;
   if ($lane->end_sequenced =~ /5/ ) {
      $seq = join('',reverse(split(//,$seq)));
      $seq =~ tr/ACGT/TGCA/;
      $insert_pos = length($seq) - $insert_pos;
      $seq_name = $lane->seq_name.'-5' unless $lane->seq_name =~ /-3$/;
      $session->info("Rev-comped sequence for Contig1      is $seq.");
   } else {
      $seq_name = $lane->seq_name.'-3' unless $lane->seq_name =~ /-3$/;
   }

   # we are adding 1 to make things label the base
   # after the insertion. NOT the interbase coordinate!
   $insert_pos++;

   if (length($seq) > $minSeqSize) {
      # we have passed all tests and are ready to insert.
      $seq = substr($seq,0,$maxSeqSize) 
               if ($maxSeqSize && length($seq) > $maxSeqSize);

      # this will be the new sequence record.
      my $seqRecord = new Seq($session);
      $seqRecord->seq_name($seq_name);

      # look for a phred_seq assembly record

      my $s_a = new Seq_AssemblySet($session,{-seq_name => $seq_name,
                                           -src_seq_src => 'phred_seq'})->select;
      foreach my $old_ass ($s_a->as_list) {
         $session->info("Old assembly had data from ".$old_ass->src_seq_id);
         if ( !exists($pidH{$old_ass->src_seq_id}) ) {
            $session->warn("New assembly does not include read from old assembly: ".$old_ass->src_seq_id.". Skipping.");
            next LANE;
         }
      } 

      # delete the old records
      map { $_->delete('src_seq_id') } ($s_a->as_list) unless $test;
      # and put in the new ones
      my $new_ass = new Seq_Assembly($session,{-seq_name => $seq_name,
                                            -src_seq_src => 'phred_seq',
                                          -assembly_date => 'today'});
      map { $new_ass->src_seq_id($_); $new_ass->insert } (keys %pidH) unless $test;
        
      my $action = 'insert';
      if ($seqRecord->db_exists) {
         $seqRecord->select;
         
         $session->info("Existing consensus sequence for this is ".$seqRecord->sequence);
         $session->info("Old assembly had insertion at ".$seqRecord->insertion_pos.", new is $insert_pos.");

         # but do not update if there are no changes.
         if ($seq eq $seqRecord->sequence && $insert_pos == $seqRecord->insertion_pos) {
            $session->info("Sequence record has not changed; maintaining old time stamp.");
            next LANE;
         } else {
            $session->log($Session::Info,"Sequence record has changed and making an update.");
            $seqRecord->last_update('today');
            $action = 'update';
         }
      }

      $seqRecord->sequence($seq);
      $seqRecord->insertion_pos($insert_pos);
      $seqRecord->strain_name($strain->strain_name);
      $seqRecord->last_update('today');
      $seqRecord->$action unless $test;

      $session->log($Session::Info,"Sequence record for ".$strain->strain_name." ".$action."'ed.");
   }

}


$session->exit();

exit(0);