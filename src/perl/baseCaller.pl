#!/usr/local/bin/perl -I../modules

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
use lib '/users/joe/src/production/utilities/';
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

# the name of a directory to look. names not prefaced by a / are
# relative to $PELEMENT_TRACE; otherwise they are absolute. *'s
# indicate that they name will be glob'ed

# the name of a directory is the gel name with an optional .number
# to indicate a sequencing attempt.

# the default path is one level below $PELEMENT_TRACE
my $path = '*';


# do we force a reload if this has been processed before?
my $force = 0;

GetOptions('lane=s@'     => $comment_db{lane},
           'well=s@'     => $comment_db{well},
           'run_date=s@' => $comment_db{run_date},
           'primer=s@'   => $comment_db{primer},
           'machine=s@'  => $comment_db{machine},
           'path=s'      => \$path,
           'force!'      => \$force,
          );
map { $comment_db{$_} = $def_comment_db{$_} unless scalar(@{$comment_db{$_}}) } keys %def_comment_db;

my $gel = new Gel($session,{-name=>$ARGV[0]})->select();

unless ($gel->id) {
   $session->error("No Gel","No gel in the db named $ARGV[0].");
   exit(1);
}

# first, look for a directory with the gel name
# next, a directory with a number attached
my $dir;
my @dirs;
if( $path =~ /^\// ) {
   $dir = (glob("$path/".$gel->name))[0];
   @dirs = glob("$path/".$gel->name.".[0-9]*");
} else {
   $dir = (glob("$PELEMENT_TRACE/$path/".$gel->name))[0];
   @dirs = glob("$PELEMENT_TRACE/$path/".$gel->name.".[0-9]*");
}
 
unless ($dir) {
   @dirs = sort { ($a=~/\.(\d+)$/)[0] <=> ($b=~/\.(\d+)$/)[0] } @dirs;
   $dir = $dirs[-1];
}
 
unless ($dir) {
   $session->error("No Dir","Cannot locate directory for ".$gel->name.".");
   exit(1);
}
 
$session->log($Session::Info,"Using directory $dir.");
 
unless ( -e $dir && -d $dir ) {
   $session->error("No Dir","Cannot find or open directory $dir for ".$gel->name.".");
   exit(1);
}
 
my @files = (glob("$dir/*.ab1"),glob("$dir/*.scf"),glob("$dir/*.SCF"));
 
$session->log($Session::Info,"There are ".scalar(@files)." lane files to process");
foreach my $file (@files) {
   my $lane = new Lane($session,{-gel_id=>$gel->id});
   
   my $chromat_type = EditTrace::TraceData::chromat_type($file);
   $session->error("File Error","Cannot determine class of chromat.") unless $chromat_type;
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
   my $seq_name = (split(/_/,$comments{sample_name}))[1];
   $lane->seq_name($seq_name);
 
   my $laneDir = (fileparse($file))[1];
   $laneDir =~ s/^$PELEMENT_TRACE\/*//;
   $lane->directory($laneDir);
   $lane->file((fileparse($file))[0]);
 
   if ($lane->db_exists ) {
      $session->log($Session::Info,"This chromat has been processed before.");
      if ( $force ) {
         $session->log($Session::Info,"Replacing old sequence.");
         $lane->delete;
      } else {
         $session->log($Session::Info,"Retaining old sequence.");
         next;
      }
   }
 

  # add the supplemental info.
  foreach my $field qw(lane well run_date machine) {
     next unless $comment_db{$field};
     my $val = join(':',map { $comments{$_} } @{$comment_db{$field}});
     # don't bother to add all blank fields. leave them null.
     $lane->$field($val) unless $val =~ /^:*$/;
  }

  # attempt to translate the primer into an 'end sequenced'. If this primer
  # does not exists in the db, we'll label it with the primer name; this
  # will need to be cleared up manually.
  my $primer = new Primer($session,{-seq_primer=>$comments{$comment_db{primer}->[0]}})->select_if_exists;
  if ($primer->end_sequenced) {
     $lane->end_sequenced($primer->end_sequenced);
  } else {
     $lane->end_sequenced($comments{$comment_db{primer}->[0]});
     $session->log($Session::Warn,"The primer ".$comments{$comment_db{primer}->[0]}." is not known to the db.");
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

  $seq->insert;
  
  $qual->phred_seq_id($seq->id);
  $qual->insert;

}

$session->exit();

exit(0);
