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

print $cgi->header("application/x-apollo");

my $filename = "$PELEMENT_XML/$name.xml";

print `cat $filename` if -e $filename;

