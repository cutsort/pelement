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
use Seq;

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
#         -force            replace an existing sequence record.
# These options are possible only if we're importing sequence from
# a single lane record
#         -start            starting coordinate of first imported base (indexed from 1)
#         -length           length of the imported

my ($gel_name,$gel_id,$lane_name,$lane_id,$force);

my $minSeqSize = 12;
my $maxSeqSize = 0;
my $start = 0;
my $length = 0;

GetOptions('gel=s'      => \$gel_name,
           'gel_id=i'   => \$gel_id,
           'lane=s'     => \$lane_name,
           'lane_id=i'  => \$lane_id,
           'min=i'      => \$minSeqSize,
           'max=i'      => \$maxSeqSize,
           'force!'     => \$force,
           'start=i'    => \$start,
           'length=i'   => \$length,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.

my ($gel,@lanes);

if ($gel_name || $gel_id) {
   unless ($gel_id) {
      $gel = new Gel($session,{-name=>$gel_name})->select_if_exists;
      $session->error("No Gel","Cannot find gel with name $gel_name.") unless $gel;
      $gel_id = $gel->id;
   }
   my $laneSet = new LaneSet($session,{-gel_id=>$gel_id})->select;
   $session->error("No Lane","Cannot find lanes with gel id $gel.") unless $laneSet;
   @lanes = $laneSet->as_list;
   if ($start || $length) {
      $session->warn("Ignoring start or length position when importing multiple lanes.");
      $start = 0;
      $length = 0;
   }
} elsif ( $lane_name ) {
   @lanes = (new Lane($session,{-file=>$lane_name})->select_if_exists);
} elsif ( $lane_id ) {
   @lanes = (new Lane($session,{-id=>$lane_id})->select_if_exists);
} else {
   $session->error("No arg","No options specified for trimming.");
   exit(2);
}

if (($start && !$length) || (!$start && $length) ) {
   $session->error("Wrong args","If one of start or length is given, both must be specified.");
   $session->exit;
   exit(2);
}

$session->log($Session::Info,"There are ".scalar(@lanes)." lanes to process");


foreach my $lane (@lanes) {

   $session->log($Session::Info,"Processing lane ".$lane->seq_name);
   # find the associated phred called sequences.
   my $phred_seq = new Phred_Seq($session,
                          {-lane_id=>$lane->id})->select_if_exists;

   unless ( $phred_seq->id ) {
      $session->log($Session::Warn,"No sequence for lane ".$lane->id.".");
      next;
   }


   my $seq;
   my $insert_pos;

   # next we need to determine the protocol for determining the insertion
   # from the trimmed portion
   my $strain = new Strain($session,{-strain_name=>$lane->seq_name})->select;
   unless ($strain && $strain->collection) {
      $session->error("No collection identifier for ".$lane->seq_name);
      exit(1);
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
         next;
      }

      my $extent;
      if ( defined($phred_seq->v_trim_end) ) {
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
         $session->error("Cannot determine trimming protocol for ".
                                                             $strain->collection);
         exit(1);
      }

      my $t_p = new Trimming_Protocol($session,{-id=>$c_p->protocol_id})->select;
      if ($t_p->id) {
         $session->log($Session::Info,"Using trimming protocol ".
                                                             $t_p->protocol_name)
                                                          if $t_p->protocol_name;
      } else {
         $session->error("Cannot determine trimming protocol for ".
                                                          $strain->collection);
         exit(1);
      }

      # this references the insertion position in an interbase coordinate.
      # if we have not found the junction, then this is -1. (before the seq)
      $insert_pos = $found_junction?$t_p->insertion_offset:-1;

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

   if (length($seq) > $minSeqSize) {
      $seq = substr($seq,0,$maxSeqSize) 
                  if ($maxSeqSize && length($seq) > $maxSeqSize);

      my $seqRecord = new Seq($session);
      $seqRecord->seq_name($lane->seq_name);

      # create a single-phred_seq assembly record

      my $s_a = new Seq_Assembly($session,{ -src_seq_id => $phred_seq->id,
                                           -src_seq_src => 'phred_seq'});
   
      my $action = 'insert';
      if ($seqRecord->db_exists) {
         $session->log($Session::Warn,
                      "Sequence record already exists; will not overwrite.") unless $force;
         $seqRecord->select;

         next unless $force;
         # but do not update if there are no changes.
         next if ($seq eq $seqRecord->sequence && $insert_pos == $seqRecord->insertion_pos);
         $session->log($Session::Info,"Sequence record has changed and forcing an update.");
         $seqRecord->last_update('today');
         $action = 'update';
         $s_a->delete('src_seq_id','src_seq_src') if $s_a->db_exists;
      }


      $seqRecord->sequence($seq);
      $seqRecord->insertion_pos($insert_pos);
      $seqRecord->strain_name($strain->strain_name);
      $seqRecord->last_update('today');
      $seqRecord->$action;

      $s_a->seq_name($seqRecord->seq_name);
      $s_a->assembly_date('today');
      $s_a->insert;

      $session->log($Session::Info,"Sequence record for ".$strain->strain_name." ".$action."'ed.");

   } else {
      $session->log($Session::Info,
                         "Sequence for ".$strain->strain_name." is below length threshold.");
   }
     
}

$session->exit();

exit(0);
