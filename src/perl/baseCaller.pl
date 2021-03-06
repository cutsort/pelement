#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  baseCaller.pl process chromatograms and extract the sequences

=head1 USAGE

  baseCaller.pl [options] <gel_name>

=cut

use Pelement;
use PCommon;
use Session;
use Gel;
use Primer;
use Lane;
use Files;
use PelementDBI;
use PhredInterface;
use Phred_Seq;
use Phred_Qual;
use IPCR;
use EditTrace::TraceData;
use EditTrace::ABIData;
use EditTrace::SCFData;

use File::Basename;
use Getopt::Long;
use strict;

my $session = new Session();

# option processing. 
# Options provide the mapping of fields in the comment area of the
# chromatogram to db fields. We want to specify lane, well, run_date
# primer, and machine. these are mapped to a colon separated list of fields
# from the comments.
# The default mapping is:
my %comment_db = (
         lane     => [],
         well     => [],
         run_date => [],
         primer   => [],
         machine  => [],
              );
my %def_comment_db = (
         lane     => ['lane'],
         well     => ['well'],
         run_date => ['stop_date'],
         primer   => ['comments'],
         machine  => ['source','machine_name'],
              );

# more option processing. 
# we specify what we are processing by the switch of either
#         -gel Name         process a gel by name
#         -gel_id Number    process a gel by internal db number id
#         -lane Name        process a lane by filename
#         -lane_id Number   process a lane by internal db number id

# the name of a directory to look. names not prefaced by a / are
# relative to $PELEMENT_TRACE; otherwise they are absolute. *'s
# indicate that they name will be glob'ed
# normally the name of a directory is the gel name with an optional .number
# to indicate a sequencing attempt.
# the default path is one level below $PELEMENT_TRACE
my $path = '*';

# do we force a reload if this has been processed before?
my $force = 0;

# variables associated with the gel/lane to process
my ($gel_name,$gel_id);

# is there a specific gel version to process? The default is
# the highest number only.
my $version = '';
my $files;

GetOptions('lane=s@'     => $comment_db{lane},
           'well=s@'     => $comment_db{well},
           'run_date=s@' => $comment_db{run_date},
           'primer=s@'   => $comment_db{primer},
           'machine=s@'  => $comment_db{machine},
           'path=s'      => \$path,
           'force!'      => \$force,
           'gel=s'       => \$gel_name,
           'gel_id=i'    => \$gel_id,
           'version=i'   => \$version,
           'file=s@'     => \$files,
          );
map { $comment_db{$_} = $def_comment_db{$_} unless scalar(@{$comment_db{$_}}) } keys %def_comment_db;

# try to select by name, then by id.
my $gel;
$gel = new Gel($session,{-name=>$gel_name})->select_if_exists if $gel_name;
$gel = new Gel($session,{-id=>$gel_id})->select_if_exists if (!$gel || !$gel->id) && $gel_id;

unless ($gel && $gel->id) {
   $session->die("No gel in the db named $gel_name.") if $gel_name;
   $session->die("No gel in the db with id $gel_id.") if $gel_id;
   $session->die("No gel specified.") if (!$gel_name && !$gel_id);
}

# first, look for a directory with the gel name
# next, a directory with a number attached
$version = ".".$version if $version;
# special case: version=0 means no version identifier.
$version = '' unless $version;

my $dir;
my @dirs;
if( $path =~ /^\// ) {
   $dir = (glob("$path/".$gel->name.$version))[0];
   @dirs = glob("$path/".$gel->name.".[0-9]*");
} else {
   $dir = (glob("$PELEMENT_TRACE/$path/".$gel->name.$version))[0];
   @dirs = glob("$PELEMENT_TRACE/$path/".$gel->name.".[0-9]*");
}
 
unless ($dir && -e $dir ) {
   @dirs = sort { ($a=~/\.(\d+)$/)[0] <=> ($b=~/\.(\d+)$/)[0] } @dirs;
   $dir = $dirs[-1];
}
 
unless ($dir) {
   $session->die("Cannot locate directory for ".$gel->name.".");
}
 
$session->log($Session::Info,"Using directory $dir.");
 
unless ( -e $dir && -d $dir ) {
   $session->die("Cannot find or open directory $dir for ".$gel->name.".");
}
 
my @files = $files? @$files : (glob("$dir/*.ab1"),glob("$dir/*.scf"),glob("$dir/*.SCF"));
 
$session->log($Session::Info,"There are ".scalar(@files)." lane files to process");
foreach my $file (@files) {
   my $lane = new Lane($session,{-gel_id=>$gel->id});
   
   my $chromat_type = EditTrace::TraceData::chromat_type($file);
   $session->die("Cannot determine class of chromat.") unless $chromat_type;
   $session->log($Session::Info,"Chromat ".(fileparse($file))[0]." has a class $chromat_type.");
 
   my $chromat = new $chromat_type;
   $chromat->readFile($file);
   # comments are extracted en masse
   my $comments = $chromat->dumpComment();
   # but we can vector-fy it
   my @comments = split(/\n/,$comments);
   # and hash-ify the
   my %comments;
   foreach my $c (@comments) {
      next unless $c =~ /\s*(\S+)\s*=\s*(.+)\s*$/;
      $comments{$1} = $2;
   }
 
   # take out the 'out-of' from the lane id;
   $comments{lane} =~ s/\/\d+//;
 
   # and the seq_name comes from the sample name
   # (after the first _ if it's there)
   my $seq_name;
   if ($comments{sample_name} =~ /_/) {
     $seq_name = (split(/_/,$comments{sample_name}))[1];
   } else {
     $seq_name = $comments{sample_name};
   }
   $lane->seq_name($seq_name);
  
   # we will not process empties.
   if ($seq_name =~ /EMPTY/i) {
      $session->log($Session::Info,"This file appears to be empty. Skipping.");
      next;
   }
 
   my $laneDir = (fileparse($file))[1];
   $laneDir =~ s/^$PELEMENT_TRACE\/*//;
   $lane->directory($laneDir);
   $lane->file((fileparse($file))[0]);
 
   if ($lane->db_exists ) {
      $session->log($Session::Info,"This chromat has been processed before.");
      if ( $force ) {
         $session->log($Session::Info,"Replacing old sequence.");
         $lane->select;
         $lane->delete('id');
      } else {
         $session->log($Session::Info,"Retaining old sequence.");
         next;
      }
   }
 

  # add the supplemental info.
  foreach my $field (qw(lane well run_date machine)) {
     next unless $comment_db{$field};
     my $val = join(':',map { $comments{$_} } @{$comment_db{$field}});
     # don't bother to add all blank fields. leave them null.
     $lane->$field($val) unless $val =~ /^:*$/;
  }

  # attempt to translate the primer into an 'end sequenced'. If this primer
  # does not exists in the db, we'll label it with the primer name; this
  # will need to be cleared up manually.
  my $primer = new Primer($session,
        {-name=>$comments{$comment_db{primer}->[0]}})->select_if_exists;
  if ($primer->end_type) {
     if ($primer->end_type eq 'b') {
        # if we cannot determine the end from the sequencing primer, 
        # we need to chase the ipcr
        $session->info("Chasing the primer to the ipcr.");
        my $end;
        my $ipcr = new IPCR($session,
                          {-name=>$gel->ipcr_name})->select_if_exists;
        $session->die("Will not be able to determine end type.")
                                                  unless $ipcr->id;
        if ($ipcr->end_type) {
          $end = $ipcr->end_type;
        } elsif ($ipcr->primer1) {
           my $primer = new Primer($session,
                          {-name=>$ipcr->primer1})->select_if_exists;
           $end = $primer->end_type
                                  if $primer->db_exists && $primer->end_type;
        } elsif (ipcr->primer2) {
           # doubtful that we'll find it here...
           my $primer = new Primer($session,
                          {-name=>$ipcr->primer2})->select_if_exists;
           $end = $primer->end_sequenced
                                  if $primer->db_exists && $primer->end_type;
        }
        $session->die("Cannot determine end type.") unless $end;
        $lane->end_sequenced($end);
     } else {
        $lane->end_sequenced($primer->end_type);
     }
  } else {
     $lane->end_sequenced($comments{$comment_db{primer}->[0]});
     $session->warn("The primer ".$comments{$comment_db{primer}->[0]}.
                                            " is not known to the db.");
  }

  $lane->insert;

  my $phred = new PhredInterface($session,{-chromat=>$file});
  $phred->run();
  my $seq = new Phred_Seq($session);
  $seq->read_file($phred->seq_file);
  my $qual = new Phred_Qual($session);
  $qual->read_file($phred->qual_file);

  $seq->lane_id($lane->id);

  # find the q20 and q30 length. These are the length of
  # the maximum runs >= 20 and 30
  my $q20 = 0;
  my $q30 = 0;
  my ($run20,$run30);
  foreach my $q (split(/\s+/,$qual->qual)) {
     $run20 = ($q >= 20)?$run20+1:0;
     $run30 = ($q >= 30)?$run30+1:0;
     $q20 = ($run20>$q20)?$run20:$q20;
     $q30 = ($run30>$q30)?$run30:$q30;
  }
  $seq->q20($q20);
  $seq->q30($q30);
  $seq->last_update('now');

  $seq->insert;
  
  $qual->phred_seq_id($seq->id);
  $qual->insert;

}

$session->exit();

exit(0);
