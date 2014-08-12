#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

autoCurate.pl examine sequence records to see it we can promote a
recheck sequence based on its mate read.

=head1 USAGE

autoCurate.pl <-gel name> | <-gel_id number> |  <-lane name> | <lane_id number>

One of gel name, gel id, lane (file) name or lane id must be specified.

=cut

use Pelement;
use PCommon;
use Session;
use Gel;
use GelSet;
use Seq;
use Lane;
use LaneSet;
use Files;
use PelementDBI;
use Phred_Seq;
use Processing;
use Seq_Assembly;
use Seq_AssemblySet;
use Seq;
use Seq_AlignmentSet;

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
#         -enzyme Name      specify the restriction enzyme used (mainly for
#                           offline processing of individual lanes)
#         -vector <seq>     specify a vector-insert junction (for offline
#                           processing of individual lanes)
#         -insert Number    specify an offset location of the insert relative
#                           to the vector-insert junction (for offline
#                           processing)
#         -test             testmode only; no updates
#         -redo             reprocess lanes where values have been set
#                           this will erase manually set values
#                           If ANY value is set, nothing will be changed

my ($gel_name,$gel_id,$lane_name,@lane_id);
my $test = 0;
my $release = 6;
my $threshold = 100;

GetOptions('gel=s'      => \$gel_name,
           'gel_id=i'   => \$gel_id,
           'lane=s'     => \$lane_name,
           'lane_id=i@' => \@lane_id,
           'test!'      => \$test,
           'release=i'  => \$release,
           'threshold=i' => \$threshold,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.

my ($gel,@lanes);

if ($gel_name || $gel_id) {
   unless ($gel_id) {
      $gel = new Gel($session,{-name=>$gel_name})->select_if_exists;
      $session->die("Cannot find gel with name $gel_name.")
                                                       unless $gel->id;
      $gel_id = $gel->id;
   }
   my $laneSet = new LaneSet($session,{-gel_id=>$gel_id})->select;
   $session->die("Cannot find lanes with gel id $gel.")
                                                       unless $laneSet;
   @lanes = $laneSet->as_list;
} elsif ( $lane_name ) {
   @lanes = (new Lane($session,{-file=>$lane_name})->select_if_exists);
} elsif ( @lane_id ) {
   map { push @lanes, (new Lane($session,{-id=>$_})->select_if_exists) }
                                                                  @lane_id ;
} else {
   $session->die("No options specified for trimming.");
}

$session->log($Session::Info,"There are ".scalar(@lanes)." lanes to process");

LANE:
foreach my $lane (@lanes) {

  $session->info("Processing lane ".$lane->seq_name);
  next if $lane->failure;

  # be certain there is enough info for processing the lane
  $session->die("End_sequenced not specified for lane ".$lane->id)
                                          unless $lane->end_sequenced;
  $session->die("Seq_name not specified for lane ".$lane->id)
                                          unless $lane->seq_name;
  $session->die("Gel_id not specified for lane ".$lane->id) 
                                          unless $lane->gel_id;


  my $p = new Phred_Seq($session,{-lane_id=>$lane->id});
  unless ($p->db_exists) {
    $session->warn("Lane ",$lane->id," has not been base called. Skipping...");
    next LANE;
  }
  $p->select;
  my @sA = new Seq_AssemblySet($session,{-src_seq_src=>'phred_seq',
                                       -src_seq_id=>$p->id})->select->as_list;
  unless (@sA) {
    $session->warn("Lane ",$lane->id," has not been used in a consensus sequence. Skipping...");
    next LANE;
  }
  for my $sA (@sA) {
    my $seq_name = $sA->seq_name;
    my $qualifier = Seq::qualifier($seq_name);
    my $can_update = 0;
    if ($qualifier) {
      if ($qualifier =~ /^r/) {
        $session->info("$seq_name is a recheck sequence.");
        my $original_seq = new Seq($session,{-seq_name=>Seq::strain($seq_name).'-'.Seq::end($seq_name)});
        if ($original_seq->db_exists) {
          $session->info("Original sequence data already exists for this line.");
        } else {
          my $alignment = new Seq_AlignmentSet($session,{-seq_name=>$seq_name,-seq_release=>$release})->select;
          if ($alignment->count) {
            (my $other_end = Seq::end($seq_name) ) =~ tr/35/53/;
            my $other_seq_name = Seq::strain($seq_name).'-'.$other_end;
            my $otherAlignment = new Seq_AlignmentSet($session,{-seq_name=>$other_seq_name,-seq_release=>$release})->select;
            if ($otherAlignment->count) {
              foreach my $a1 ($otherAlignment->as_list) {
                next unless $a1->status eq 'unique' || $a1->status eq 'curated' || $a1->status eq 'autocurated';
                foreach my $a2 ($alignment->as_list) {
                  if ($a1->scaffold eq $a2->scaffold && abs($a1->s_insert - $a2->s_insert) < $threshold
                          && ($a1->s_start-$a1->s_end)*($a1->s_start-$a1->s_end) > 0) {
                    $session->info("$seq_name has a consistent alignment. Can update.");
                    unless ($test) {
                      my $new_seq_name = Seq::strain($seq_name).'-'.Seq::end($seq_name);
                      $session->db_begin;
                      $session->db->do("set constraints all deferred");
                      foreach my $table (qw(seq_alignment seq_assembly blast_run seq)) {
                        $session->info("Command: update $table set seq_name='$new_seq_name' where seq_name='$seq_name'");
                        $session->db->do("update $table set seq_name='$new_seq_name' where seq_name='$seq_name'");
                      }
                      $session->db_commit;
                    }
                    $can_update = 1;
                    next LANE;
                  }
                }
              }
            } else {
              $session->info("$other_seq_name does not have any alignments. Skipping.");
            }
          } else {
            $session->info("$seq_name does not have any alignments. Skipping.");
          }
        }
      } else {
        $session->info("Skipping qualifier $qualifier.");
      }
    } else {
      $session->info("$seq_name is unqualified.");
    }
  }
}

$session->exit();

exit(0);

