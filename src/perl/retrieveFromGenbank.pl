#!/usr/local/bin/perl -w
#
# A quickie to retrieve the sequence form genbank so that we can compare
# it to our local copy
#

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use Getopt::Long;

use strict;
my $destDir = ".";
my $echo = 0;

# search by title (default) or accession number
my $title = 1;
my $save_all = 0;

my $ua = new LWP::UserAgent;

GetOptions("output=s" => \$destDir,
           "title!"   => \$title,
           "echo!"    => \$echo,
           "save!"    => \$save_all);


$title = $title?"[TITL]":"[ACCN]";

while (<STDIN>) {

chomp $_;
my ($strain) = split(/[\t ]+/,$_);


my $entrez = 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Search&'.
          'db=nuccore&term="'.$strain.'"'.$title.
          '&doptcmdl=FASTA&mode=text';

print "$entrez\n" if ($echo);
my $request = new HTTP::Request(GET=>"$entrez");
my $response = $ua->request($request);
my $entry = $response->as_string;
##next unless $entry =~ />>gi/;
(my $sequence = $entry) =~ s/^.*>>gi(.*)<\/pre>.*$/>gi$1/s;
$sequence =~ s/<pre>//s;
if ($save_all) {
  open(GB,">$destDir/$strain.gb");
  print GB $entry,"\n";
  close(GB);
} else {
  open(FST,">$destDir/$strain.fasta");
  print FST "$sequence\n";
  close(FST);
}

}
