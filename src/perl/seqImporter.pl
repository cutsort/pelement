#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqImporter.pl process database record of phred sequence and 
  create a consensus sequence from all available data

=head1 USAGE

  seqTrimmer.pl [options] <-gel name>|<-gel_id number>|<-lane name>|<lane_id number>

  One of gel name, gel id, lane (file) name or lane id must be specified.

=head1 Options

=item  -min N

  The minimum length of sequence to import (default 12)

=item  -max N

  The maximum length of sequence to import. Set to 0 for unlimited (default unlimited)

=cut

use Pelement;
use PCommon;
use Session;
use Gel;
use Lane;
use LaneSet;
use Strain;
use Trimming_Protocol;
use Collection_Protocol;
use Files;
use PelementDBI;
use Phred_Seq;
use Seq_Assembly;
use Seq_AssemblySet;
use Seq;
use SeqSet;

# George's sim4-er
use GH::Sim4;

use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();

# the default path is one level below $PELEMENT_TRACE

# option processing. 
# we specify what we are processing by the switch of either
#         -gel Name         process a gel by name
#         -gel_id Number    process a gel by internal db number id
#         -lane Name        process a lane by filename
#         -lane_id Number   process a lane by internal db number id
#         -seq seq_name     process a lane by a seq name (with optional end)
#                           this will only import the earliest sequence if there
#                           is more than 1.
# These options are possible only if we're importing sequence from
# a single lane record
#         -start            starting coordinate of first imported base
#                           (indexed from 1)
#         -length           length of the imported
#
#         -attr key=value   override a key,value combination when processing
# 
# These options specify how to process the lane(s). Default is
# to import a sequence record for a strain in which there is no
# previous sequence record and skip it if there is an existing record.
#         -force            replace an existing sequence record.
#         -recheck          import a lane as an 'unconfirmed recheck'

my ($gel_name,$gel_id,$lane_name,$lane_id,$seq_name,$force,$recheck);

my $minSeqSize = 12;
my $maxSeqSize = 0;
my $start = 0;
my $length = 0;
my @attributes;
my $test = 0;      # test mode only. No inserts or updates.

GetOptions('gel=s'      => \$gel_name,
           'gel_id=i'   => \$gel_id,
           'lane=s'     => \$lane_name,
           'lane_id=i'  => \$lane_id,
           'seq=s'      => \$seq_name,
           'min=i'      => \$minSeqSize,
           'max=i'      => \$maxSeqSize,
           'force!'     => \$force,
           'recheck!'   => \$recheck,
           'start=i'    => \$start,
           'length=i'   => \$length,
           'attr=s@'    => \@attributes,
           'test!'      => \$test,
          );


# start a transaction. we may have to temporarily violate constraints.
$session->db_begin();

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver
# something) gels by name are first, then by gel_id, then by lane name,
# then by lane_id.


my ($gel,@lanes);

if ($gel_name || $gel_id) {
   unless ($gel_id) {
      $gel = new Gel($session,{-name=>$gel_name})->select_if_exists;
      $session->die("Cannot find gel with name $gel_name.") unless $gel;
      $gel_id = $gel->id;
   }
   my $laneSet = new LaneSet($session,{-gel_id=>$gel_id})->select;
   $session->die("Cannot find lanes with gel id $gel.") unless $laneSet;
   @lanes = $laneSet->as_list;
   if ($start || $length) {
      $session->warn(
        "Ignoring start or length position when importing multiple lanes.");
      $start = 0;
      $length = 0;
   }
} elsif ( $lane_name ) {
   @lanes = (new Lane($session,{-file=>$lane_name})->select_if_exists);
} elsif ( $lane_id ) {
   @lanes = (new Lane($session,{-id=>$lane_id})->select_if_exists);
} elsif ( $seq_name ) {
   my ($seq,$end) = Seq::parse($seq_name);
   undef $end if $end eq 'b';
   my @all_lanes = new LaneSet($session,
             {-seq_name=>$seq,-end_sequenced=>$end})->select->as_list;
   # a temp hash to keep track of the ends
   my %earliest;
   map { $earliest{$_->end_sequenced} = $_ if  !($_->failure ) &&
        (!exists($earliest{$_->end_sequenced}) ||
         ($_->run_date cmp $earliest{$_->end_sequenced}->run_date) == -1) }
                                                                @all_lanes;
   @lanes = values %earliest;
} else {
   $session->die("No options specified for trimming.");
}

if (($start && !$length) || (!$start && $length) ) {
   $session->die("If one of start or length is given, both must be specified.");
}

$session->log($Session::Info,"There are ".scalar(@lanes)." lanes to process");


LANE:
foreach my $lane (@lanes) {

   $session->log($Session::Info,"Processing lane ".$lane->seq_name);

   map { my ($key,$value) = split(/\s*=\s*/,$_);
         $lane->$key($value) if $key && $value;
       } @attributes;

   if (is_true($lane->failure)) {
      $session->info("This lane has been marked as a failure. Skipping.");
      next LANE;
   }

   # find the associated phred called sequences.
   my $phred_seq = new Phred_Seq($session,
                          {-lane_id=>$lane->id})->select_if_exists;

   unless ( $phred_seq->id ) {
      $session->log($Session::Warn,"No sequence for lane ".$lane->id.".");
      next LANE;
   }


   my $seq;
   my $insert_pos;

   # next we need to determine the protocol for determining the insertion
   # from the trimmed portion
   my $strain = new Strain($session,{-strain_name=>$lane->seq_name})->select;
   unless ($strain && $strain->collection) {
      $session->die("No collection identifier for ".$lane->seq_name);
   }

   if ($start) {
      $seq = substr($phred_seq->seq,$start-1,$length);
   } else {
  
      my $found_junction = 1;
      unless ( $phred_seq->v_trim_start ) {
         $session->log($Session::Warn,"Sequence for ".$phred_seq->id.
                                    " is not vector trimmed at the start.");
         # if we have not found the vector junction, then start with
         # the quality. We'll check next that this exists.
         $phred_seq->v_trim_start($phred_seq->q_trim_start);
         $found_junction = 0;
      }

      unless ( defined($phred_seq->q_trim_start) && $phred_seq->q_trim_end ) {
         $session->log($Session::Warn,"Sequence for ".$phred_seq->id.
                                         " is not quality trimmed.");
         next LANE;
      }

      my $extent;
      if ( defined($phred_seq->v_trim_end) ) {
         # these will be ambiguous; the entired seq may be low quality.
         if (!$found_junction &&
               $phred_seq->v_trim_end < $phred_seq->q_trim_start) {
            $session->info("Sequence has no vector junction and high ".
                           "quality after a possible end site. Skipping.");
            next LANE;
         }
         $extent = ($phred_seq->q_trim_end > $phred_seq->v_trim_end)?
                    $phred_seq->v_trim_end : $phred_seq->q_trim_end;
      } else {
         # we've already checked that there a quality end trim
         $extent = $phred_seq->q_trim_end;
      }


      my $c_p = new Collection_Protocol($session,
                          {-collection=>$strain->collection,
                           -like=>{end_sequenced=>'%'.$lane->end_sequenced.'%'}}
                                                        )->select;
      unless ($c_p->protocol_id) {
         $session->die("Cannot determine trimming protocol for ".
                                                    $strain->collection);
      }

      my $t_p = new Trimming_Protocol($session,{-id=>$c_p->protocol_id}
                                                               )->select;
      if ($t_p->id) {
         $session->log($Session::Info,"Using trimming protocol ".
                                 $t_p->protocol_name) if $t_p->protocol_name;
      } else {
         $session->die("Cannot determine trimming protocol for ".
                                                          $strain->collection);
      }

      # this references the insertion position in an interbase coordinate.
      # if we have not found the junction, then this is -1. (before the seq)
      $insert_pos = $found_junction?$t_p->insertion_offset:-1;

      if ($extent <= $phred_seq->v_trim_start) {
         $session->warn("No sequence after trimming.");
         next LANE 
      }


      $seq = substr($phred_seq->seq,$phred_seq->v_trim_start,
                                     $extent-$phred_seq->v_trim_start);
   }

   my $gel = new Gel($session,{-id=>$lane->gel_id})->select;
   if ($lane->end_sequenced =~ /5/ ) {
      $lane->seq_name($lane->seq_name.'-5') unless $lane->seq_name =~ /-5$/;
      $seq = join('',reverse(split(//,$seq)));
      $seq =~ tr/ACGT/TGCA/;
      $insert_pos = length($seq) - $insert_pos;
   } else {
      $lane->seq_name($lane->seq_name.'-3') unless $lane->seq_name =~ /-3$/;
   }

   # we are adding 1 to make things label the base
   # after the insertion. NOT the interbase coordinate!
   $insert_pos++;


   if (length($seq) < $minSeqSize) {
      $session->log($Session::Info,"Sequence is not long enough to add into the db. Skipping");
       next LANE;
   }


   $seq = substr($seq,0,$maxSeqSize) 
               if ($maxSeqSize && length($seq) > $maxSeqSize);
   # we'll dummy up a putative new sequence record to pass to the
   # inserters. Some of this info may be changed prior to insertion
   my $seqRecord = new Seq($session,{ -sequence => $seq,
                                      -seq_name => $lane->seq_name,
                                      -insertion_pos => $insert_pos,
                                      -strain_name => $strain->strain_name});

   if ( $recheck ) {
      insertRecheckRecord($session,$seqRecord,$phred_seq,$force);
   } else {
      insertNewRecord($session,$seqRecord,$phred_seq,$force);
   }

     
}

if ($test) {
   $session->info("Aborting transaction.");
   $session->db_rollback;
} else {
   $session->db_commit;
}

$session->exit();

exit(0);

sub insertRecheckRecord
{
   # we're going to insert a sequence record marked with the 'recheck'
   # qualifier; but only if this sequence is not part of some multiple
   # sequence consensus. 
   # If this is already a single read sequence, it will also be skipped
   # unless the force flag has been specified.

   my ($session,$seqRecord,$phred_seq,$force) = @_;
 
   # first, see if this sequence is part of anything.
   my $s_a = new Seq_Assembly($session,{ -src_seq_id => $phred_seq->id,
                                        -src_seq_src => 'phred_seq'});
   if ($s_a->db_exists) {
      ($session->info("This phred seq was part of an existing sequence assembly. Skipping.")
                                                     and return) unless $force;
      $session->info("This phred seq was part of an existing sequence assembly. Overwriting.");
      # but first, see if it was assembled.
      my $s_a_S = new Seq_AssemblySet($session,{-seq_name=>$s_a->seq_name});

      # see hommany returns records.
      $s_a_S->select;
      if (scalar($s_a_S->as_list) > 1) {
         $session->info("This phred seq is assembled into a multiple sequence consensus. Skipping.");
         return;
      }
      $session->die("The code for updating recheck seqs is not finished.");
      foreach my $o ($s_a_S->as_list) {
         $o->delete('src_seq_id','src_seq_src');
      }
   }

   # find out the list of unconfirmed recheck seq's
   my $sS = new SeqSet($session,{-like=>{seq_name=>$seqRecord->seq_name.'.r%'}})->select;
   $session->info("This sequence already has ".scalar($sS->as_list)." unconfirmed recheck sequences.");
   my $newId = 1;
   map { if ($_->qualifier =~ /r(\d+)/) { $newId = ($newId>$1)?$newId:($1+1) } } $sS->as_list;

   $session->info("Inserting unconfirmed recheck as r$newId.");
   $seqRecord->seq_name($seqRecord->seq_name.".r$newId");
   $seqRecord->last_update('now');
   $seqRecord->insert;

   $s_a->seq_name($seqRecord->seq_name);
   $s_a->assembly_date('today');
   $s_a->insert;

   # return 'true' if ok. We're not checking this (yet).
   return 1;
}

sub insertNewRecord
{
   # create a single-phred_seq assembly record
   my ($session,$seqRecord,$phred_seq,$force) = @_;
 
   my $newRecord = new Seq($session);
   $newRecord->seq_name($seqRecord->seq_name);

   my $s_a = new Seq_Assembly($session,{ -src_seq_id => $phred_seq->id,
                                        -src_seq_src => 'phred_seq'});
   
   my $action = 'insert';
   my $noChanges = 0;
   if ($newRecord->db_exists) {
      $session->log($Session::Warn,
                   "Sequence record already exists; will not overwrite.")
                                                            unless $force;
      return unless $force;
      $newRecord->select;
      # but do not update if there are no changes.
      $noChanges = 1 if ($seqRecord->sequence eq $newRecord->sequence &&
                       $seqRecord->insertion_pos == $newRecord->insertion_pos);
      $session->log($Session::Info,
                 "Sequence record has changed and forcing an update.")
                                                        unless $noChanges;
      $newRecord->last_update('now');
      $action = 'update';
      my $old_assem = new Seq_AssemblySet($session,
                         {-src_seq_src => 'phred_seq',
                          -seq_name    => $newRecord->seq_name})->select;
      foreach my $o ($old_assem->as_list) {
         $o->delete('src_seq_id','src_seq_src');
      }
   }

   $newRecord->sequence($seqRecord->sequence);
   $newRecord->insertion_pos($seqRecord->insertion_pos);
   $newRecord->strain_name($seqRecord->strain_name);
   $newRecord->last_update('now');
   $newRecord->$action unless $noChanges;

   # what we're doing here is updating the sequence assembly
   # record with the current datestamp even for the cases of
   # the sequence record does not have an updated datestamped.
   # This will deal with the problem of migrating the sequence
   # assembly info into the db over time.
   $s_a->seq_name($newRecord->seq_name);
   $s_a->assembly_date('today');
   $s_a->insert;

   $session->log($Session::Info,"Sequence record for ".$newRecord->seq_name.
                                 " ".$action."'ed.");

   # return 'true' if ok. We're not checking this (yet).
   return 1;
}
