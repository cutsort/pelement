=head1 Files.pm

  static routines for file manipulation

=cut

package Files;

use File::Copy;
use File::Basename;
use Digest::MD5;

use strict;
use Pelement;

sub make_temp
{
   # generate a new file name by replacing X's in a template 
   # with numbers until the file name is unique

   my $template = shift;
   
   $template = $PELEMENT_TMP.$template unless $template =~ /^\//;

   my $Xs;
   if ( $template =~ /X/ ) {
     ($Xs = $template) =~ s/.*?(X+).*/$1/;
   } else {
     $Xs = "";
   }

   my $nXs = length($Xs);
   my $maxCntr = 10**($nXs);

   my $cntr = 0;
   my $newFile;

   return $template if (!-e $template && !$nXs);
   return "" if (-e $template && !$nXs);

   do {
      my $cntrString = sprintf("%${nXs}.${nXs}d",$cntr);
      $cntr++;
      ($newFile = $template) =~ s/X+/$cntrString/;
      } while (-e $newFile && $cntr < $maxCntr );

   return $newFile unless $cntr == $maxCntr;
   return "";

}
sub file_timestamp
{
  return (stat(shift))[9];
}

sub file_date
{
  return PCommon::time_value(file_timestamp(shift));
}

=head1 write

   Create a file and fill it with this stuff.

=cut
sub write
{
   my ($fname,$contents) = @_;
   open(FIL,"> $fname") or return;
   print FIL $contents or return;
   close(FIL) or return;
   return 1;
}

sub touch
{
   my $fname = shift;

   if (-e $fname ) {
      open(TMP,">> $fname") or (warn "Cannot open $fname." and return);
   } else {
      open(TMP,"> $fname") or (warn "Cannot create $fname." and return);
   }

   # how can we tell if this is successful? it should return 0.
   syswrite TMP, '', 0;

   close TMP or return;
   return 1;
}
=head1 append

  Copy the contents of 1 source file to the end of a target. The
  destination file need not already exist. 1 is return on success.

=cut

sub append
{
   my ($source,$target) = @_;

   my $bufSize = 8192;
   my $buffer;

   return unless -e $source;

   if (-e $target) {
      open(OUT,">> $target") or return;
   } else {
      open(OUT,"> $target") or return;
   }

   open(IN,"<$source") or (close(OUT),return);

   my $iJustRead;
   while( ($iJustRead = read(IN,$buffer,$bufSize)) > 0 ) {
      syswrite(OUT,$buffer,$iJustRead) or warn "Trouble writing to $target: $!";
   }

   close(IN) or warn "Trouble closing $source: $!";
   close(OUT) or warn "Trouble closing $target: $!";
   return 1;
}

sub delete
{
   return unlink shift;
}

sub copy
{
   return File::Copy::copy(@_);
}

sub md5sum
{
   my $file = shift;
   return unless -e $file;

   open(FILE,"< $file") or return;
   binmode(FILE);
   my $md5 = new Digest::MD5;
   $md5->addfile(*FILE);
   close(FILE);
   return $md5->hexdigest;
}

1;
