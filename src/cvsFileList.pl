#!/usr/local/bin/perl 

=head1 Name

   cvsFileList.pl

=head1 Description

   A utility printing the paths of files in CVS. Used in making tar files

=head1 Usage

   no arguments or options. 

=cut

use File::Find;

File::Find::find(\&inCVS,'.');

sub inCVS
{
  return unless $File::Find::name =~ /CVS\/Entries/;
  open(FIL,$_) or die "Some trouble opening $_: $!";
  while( <FIL> ) {
    next if /^D/;
    (my $dir = $File::Find::dir) =~ s/CVS$//;
    my $file = $dir.(split(/\//,$_))[1];
    print $file,"\n";
  }
  close(FIL);
}

