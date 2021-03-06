#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  seqTrimmer.pl process database record of phred sequence and 
  quality and trim by quality and vector.

=head1 USAGE

  moveTraces.pl 

=cut

use Pelement;
use PCommon;
use Processing;
use Session;
use Gel;
use Files;

use File::Basename;
use Getopt::Long;
use Digest::MD5;
use strict;

my $session = new Session();

# option processing. 
# we specify what we are processing by the switch of either

# if we're just moving 1 gel, we need to specify
my $gel_name = '';
# the version to use
my $version = 1;
# delete the source after copying
my $deleteSrc = 1;
my $force;
GetOptions( "gel=s"     => \$gel_name,
            "version=i" => \$version,
            "delete!"   => \$deleteSrc,
            "force!"    => \$force,
           );

# look at the inbox directory and search for directories of new gels

# a hash of directories that this process is copying to
my %iMade = ();

GEL:
foreach my $dir (glob("$PELEMENT_INBOX/*")) {
   next unless -d $dir;
   $session->info("Looking at directory $dir.");
   my $deleteDir = $deleteSrc;
   my @file_list = glob("$dir/*.ab1");
   $session->info("There are ".scalar(@file_list)." files to transfer.");
   foreach my $file (@file_list) {
      $session->debug("Looking at file $file.");
      my $gel_from_file = gel_from_file($file);
      next unless $gel_from_file;
      next if ($gel_name && $gel_name ne $gel_from_file);
      my $target = Gel::default_dir($gel_from_file,$version);
      $session->info("Looking for directory $target");
      if ( -e $target && !$iMade{$target} && !$force) {
         $session->info("Target directory for $gel_from_file exists. Assuming this was processed.");
         next GEL;
      } else {
         unless ( -e $target ) {
            $session->info("Target directory for $gel_from_file does not exist.");
            mkdir($target) or
                $session->die("Cannot create directory $target: $!");
            $iMade{$target} = 1;
         }
         $session->info("Copying $file to $target.");
         Files::copy($file,$target) or
                $session->die("Cannot copy $file to $target: $!");

         # what is the exact name of the new file?
         my $newFile = (File::Basename::fileparse($target))[1] .'/'. (File::Basename::fileparse($file))[0];
         if (!-e $newFile) {
            $session->die("Some trouble locating copied file $newFile: $!");
         } elsif (Files::md5sum($file) ne Files::md5sum($newFile)) {
            $session->warn("MD5 sum of files do not agree. Not deleting.");
            $deleteDir = 0;
         } elsif ($deleteSrc) {
            $session->info("Deleting source $file.");
            # last chance check for errors: suppose the source and target are identical. This is
            # the case if the dev and inode are the same.
            if ( ( (stat($file))[0]==(stat($target))[0] ) && ( (stat($file))[1]==(stat($target))[1] ) ) {
               $session->warn("Source and target of copy are identical. Not deleting.");
               $deleteDir = 0;
            } else {
               Files::delete($file) or ($session->warn("Trouble deleting $file.") && ($deleteDir = 0));
            }
         } else {
            $session->info("Copy was successful but preserving file.");
            $deleteDir = 0;
         }
      }
   }
   (rmdir($dir) or $session->warn("Trouble deleting directory $dir")) if $deleteDir;
}


$session->exit();

exit(0);

sub gel_from_file
{
  my $file = File::Basename::basename(shift,'.ab1');
  my @fields = split(/_/,$file);
  return $fields[2] if $fields[1] eq 'RD';
  return $fields[0] if $fields[0] =~ /PT\d+/;
}
