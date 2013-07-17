#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  seqDownload.pl Web script for downloading sequence

=cut

use Pelement;
use Session;
use PelementCGI;

$cgi = new PelementCGI;


if ($cgi->param('seq_name')) {
   spewSeq($cgi);
} else {
   print $cgi->header();
   print $cgi->init_page({-title=>"Sequence Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
   print $cgi->banner();
   selectSeq($cgi);
   print $cgi->footer();
   print $cgi->close_page();
}

exit(0);

sub selectSeq
{

   my $cgi = shift;

   # still need to write

}

sub spewSeq
{
   my $cgi = shift;
   my $session = new Session({-log_level=>0});

   my $seq = $session->Seq({-seq_name=>$cgi->param('seq_name')})->select_if_exists;
   if ($seq->sequence) {
     print $cgi->header(-type=>"text/plain",
            -content_disposition=>"attachment; filename=".$seq->seq_name.'.fasta');

     my $bases = $seq->sequence;
     $bases =~ s/(.{50})/$1\n/g;
     $bases .= "\n";
     $bases =~ s/\n\n/\n/g;
     print ">",$seq->seq_name,"\n",$bases;

   }
   $session->exit;
}
