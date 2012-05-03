#!/usr/local/bin/perl -I../modules

=head1 NAME

  migrateAlignments.pl transfer alignment curations from one blast run to another

=head1 USAGE

  migrateAlignments.pl [options] <seq_name>

=head1 DESCRIPTION

  After a sequence is modified, re-blasted and re-aligned, any
  non-automatic alignments from the old set need to be transferred to
  the new blast results. The first blast run may have resulted in 
  alignments that were labeled as 'curated' or 'deselected'. The
  new blast run may hit these same HSP's. We need to associated
  the HSP's with one another and transfer the curations whenever
  possible.

  We're assuming that any changes in the sequences are improvements:
  anything that used to be an automatic alignment which now requires a
  curation should not be promoted.

=cut

use Pelement;
use PCommon;
use PelementDBI;
use Session;
use Seq_Alignment;
use Seq_AlignmentSet;
use Blast_Report;
use Blast_ReportSet;
use Files;
use strict;

use Getopt::Long;

my $session = new Session();

my $test = 0;     # just looking
my $src_db = 3;   # alignments to start with
my $dest_db = 5;  # alignments to end with
GetOptions( "test!" => \$test,
            "src=i" => \$src_db,
            "dest=i" => \$dest_db,);

# we're assuming we're moving between releases.
$session->die("This can only be used to map alignments between releases.")
                 if $src_db == $dest_db;

my $seq_name = $ARGV[0];

my $seq = new Seq($session,{-seq_name=>$seq_name});

$session->die("There is no record for sequence $seq_name.") unless $seq->db_exists;
$seq->select;

my $insert_pos = $seq->insertion_pos;

# the old alignments
my $oldAlign = new Seq_AlignmentSet($session,{-seq_name=>$seq_name,
                                          -seq_release=>$src_db})->select;

$session->info("Selected ",$oldAlign->count," old alignment records.");
if ($test) {
   map { $session->info("An old alignment is at ".
                   $_->scaffold." at ".$_->s_insert) } $oldAlign->as_list;
} 

# and the new
my $newAlign = new Seq_AlignmentSet($session,{-seq_name=>$seq_name,
                                          -seq_release=>$dest_db})->select;
$session->info("Selected ",$newAlign->count," new alignment records.");
if ($test) {
   map { $session->info("An new alignment is at ".
                   $_->scaffold." at ".$_->s_insert) } $newAlign->as_list;
} 

if ($oldAlign->count==0) {
  $session->info("There is nothing to transfer.");
} elsif ($oldAlign->count == 1 ) {
  if ( $newAlign->count == 1 ) {
    # unique to unique? good
    my $old = ($oldAlign->as_list)[0];
    my $new = ($newAlign->as_list)[0];
    if ($old->scaffold eq $new->scaffold) {
      # good enuf
      createTransferRecord($session,$old,$src_db,$new,$dest_db,'Unique to Unique',1);
      $new->status($old->status);
      $new->update;
    } else {
      createTransferRecord($session,$old,$src_db,$new,$dest_db,'Different Arm',0);
    }
  } elsif ( $newAlign->count == 0 ) {
    # there are no alignments. Look at the blast report and make an
    # alignment. Then curate
    my $old = ($oldAlign->as_list)[0];
    my $approx = findGuess($session,$old->scaffold,$old->s_insert);
    if ($approx) {
      my $slop = 100 + length($seq->sequence);
      my $bRSet = new Blast_ReportSet($session,{-seq_name=>$seq_name,
                                              -db => 'release5_genomic',
                                              -name => $old->scaffold,
                                              -greater_than=>{subject_begin=>$approx-$slop},
                                              -less_than=>{subject_end=>$approx+$slop}})->select;
      if ($bRSet->count==1) {
        $session->verbose("Generating and curating alignment.");
        my $newA = new Seq_Alignment($session);
        $newA->from_Blast_Report(($bRSet->as_list)[0]);
        $newA->status($old->status);
        $newA->insert;
        createTransferRecord($session,$old,$src_db,$newA,
                    $dest_db,'Selected and curated',1);
      } elsif ($bRSet->count>1) {
        $session->verbose("Ambiguous, picking one closest to end.");
        my $new = ($bRSet->as_list)[0];
        # we could probably do this as a sort...
        foreach my $try_n ($bRSet->as_list) {
          if ($seq_name =~ /-3/) {
            $new = $try_n if $try_n->query_begin < $new->query_begin;
          } elsif ($seq_name =~ /-5/) {
            $new = $try_n if $try_n->query_end > $new->query_end;
          } else {
            $new = '';
          }
        }
        if ($new) {
          my $newA = new Seq_Alignment($session);
          $newA->from_Blast_Report($new);
          $newA->status($old->status);
          $newA->insert;
          createTransferRecord($session,$old,$src_db,$newA,
                    $dest_db,'Closest',1);
        } else {
          createTransferRecord($session,$old,$src_db,
             new Seq_Alignment($session,{-seq_name=>$old->seq_name,
                                         -seq_release=>5}),
                    $dest_db,'Needs curation',0);
        }
      } else {
        $session->verbose("Not found, needs curation.");
        createTransferRecord($session,$old,$src_db,
             new Seq_Alignment($session,{-seq_name=>$old->seq_name,
                                         -seq_release=>5}),
                    $dest_db,'Needs curation',0);
      }
    } else {
      $session->verbose("Not found, needs curation.");
      createTransferRecord($session,$old,$src_db,
           new Seq_Alignment($session,{-seq_name=>$old->seq_name,
                                       -seq_release=>5}),
                  $dest_db,'Needs curation',0);
    }
       
  } else {
    # this needs looking at; this will point to a null rel-5 record
    my $old = ($oldAlign->as_list)[0];
    createTransferRecord($session,$old,$src_db,
           new Seq_Alignment($session,{-seq_name=>$old->seq_name,
                                       -seq_release=>5}),
                  $dest_db,'Needs curation',0);
  }
} else {
  # a hash by arm?
  foreach my $old ($oldAlign->as_list) {
    next if $old->status eq 'multiple';
    
    createTransferRecord($session,$old,$src_db,
             new Seq_Alignment($session,{-seq_name=>$old->seq_name,
                                         -seq_release=>5}),
                    $dest_db,'Multi-multi',0);
  }
  $session->info("have not written multi-alignments yet.");
}
  
$session->exit();

exit(0);

sub createTransferRecord
{
  my $session = shift;
  my $old = shift;
  my $old_db = shift;
  my $new = shift;
  my $new_db = shift;
  my $status = shift;
  my $success = shift;

  $session->die("Huh") unless $old->seq_name eq $new->seq_name;

  my $record = $session->Alignment_Transfer(
                          {-seq_name=>$old->seq_name,
                           -old_scaffold => $old->scaffold,
                           -old_insert   => $old->s_insert,
                           -old_status   => $old->status,
                           -old_release  => $old_db,
                           -new_scaffold => $new->scaffold,
                           -new_insert   => $new->s_insert,
                           -new_status   => $new->status,
                           -new_release  => $new_db,
                           -transfer_status => $status,
                           -success       => $success})->insert;
}

sub findGuess
{
  my $session = shift;
  my $arm = shift;
  my $point = shift;

  return unless $arm =~ /^arm_/;

  $arm =~ s/arm_//;

  my $find = $session->db->select_value(qq(select r3_r5_map('$arm',$point)));
  return $find if $find;
  my $inc = 1;
  while (1) {
    $find = $session->db->select_value(qq(select r3_r5_map('$arm',$point+$inc)));
    return $find if $find;
    $find = $session->db->select_value(qq(select r3_r5_map('$arm',$point-$inc)));
    return $find if $find;
    $inc++;
    return if $inc > 1000;
  }
}
