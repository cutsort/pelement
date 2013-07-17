#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  processCmd.pl what is the next processing step for a gel?

=head1 USAGE

  processCmd.pl [options]

=cut

use Pelement;
use PCommon;
use Session;
use Gel;
use LaneSet;
use Lane;
use Phred_Seq;
use Seq;
use Seq_Assembly;
use PelementDBI;


use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();

# variables associated with the gel/lane to process
my ($gel_name,$gel_id);

GetOptions('gel=s'       => \$gel_name,
           'gel_id=i'    => \$gel_id,
          );
# try to select by name, then by id.
my $gel;
$gel = new Gel($session,{-name=>$gel_name})->select_if_exists if $gel_name;
$gel = new Gel($session,{-id=>$gel_id})->select_if_exists if (!$gel || !$gel->id) && $gel_id;

my $cmd;
unless($gel->db_exists) {
   $session->verbose("The specified gel does not exists in the db.");
} else {
   my $lS = new LaneSet($session,{-gel_id=>$gel->id})->select;
   my $any_trimmed = 0;
   my $any_imported = 0;
   my $any_other_imported = 0;
   unless ($lS->as_list) {
      $session->verbose("The gel has no lanes; run the base caller.");
      $cmd = "baseCaller.pl -gel ".$gel->name;
   } else {
      foreach my $lane ($lS->as_list) {
         my $pS = new Phred_Seq($session,{-lane_id=>$lane->id});
         unless ($pS->db_exists) {
            $session->die("Lane is registered but not phred seq?");
         }
         $pS->select;
         # trimmed?
         $any_trimmed++ if( $pS->q_trim_start || $pS->q_trim_end ||
                            $pS->v_trim_start || $pS->v_trim_end);
         # imported?
         my $seqA = new Seq_Assembly($session,{-src_seq_src=>'phred_seq',
                                               -src_seq_id => $pS->id});
         $any_imported++ if $seqA->db_exists;
         # any other with this strain and end?
         my $seq = new Seq($session,{-seq_name=>$lane->seq_name.'-'.$lane->end_sequenced});
         $any_other_imported++ if $seq->db_exists;
      }
   }

   if (!$any_trimmed) {
      $session->info("No sequences have been trimmed.");
   } elsif (!$any_imported && !$any_other_imported) {
      $session->info("No sequences have been imported.");
   } elsif (!$any_imported && $any_other_imported) {
      $session->info("Need to process as a recheck.");
   }
}
$session->exit;
