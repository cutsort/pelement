#!/usr/local/bin/perl -I../modules

=head1 NAME

   retrieveXML.pl transfer XML for a specified segment

=head1 USAGE

   http://server:port/cgi-bin/retrieveXML.pl?name=AENNNNNN

  This is only a test implementation! honest.

=cut

use strict;
use Pelement;
use PelementCGI;

my $cgi = new PelementCGI;
# Get the args
my $name = $cgi->param('name');

$name =~ s/\.xml$//;

# strip off any possible directory references. It's not
# polite to try to hack in.
$name =~ s:.*[/]::;

&error($cgi,"<No scaffold specified>") unless $name;

if ($name eq 'pelementXML') {
   # special case. The whole thing.
   my $filename = "$PELEMENT_XML/pelementXML.tar.gz";
   &error($cgi,$name) unless -e $filename;
   print $cgi->header(-type=>"application/gzip-compressed",-content_disposition=>"attachment; filename=pelementXML.tar.gz");
   spew($filename);
} else {
   my $filename = "$PELEMENT_XML/$name.xml";
   &error($cgi,$name) unless -e $filename;
   print $cgi->header(-type=>"application/x-apollo",-content_disposition=>"attachment; filename=$name.xml");
   spew($filename);
}

sub spew
{
   my $filename = shift;
   my $buffer;

   # the size of our I/O hunk
   my $bufferSize = 5000;

   open(FIL,"$filename") or return;

   while( read(FIL,$buffer,$bufferSize) ) {
      print $buffer;
   }

   close(FIL);
}

sub error
{
   my $cgi = shift;
   my $noFound = shift;
   
   print $cgi->header();
   print $cgi->init_page();
   print $cgi->banner();

   print $cgi->h3("Cannot find the file for $name."),"\n";

   print $cgi->footer();
   print $cgi->close_page();

   exit(0);
}
