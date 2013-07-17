#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  logout.pl Web user_id un-setter

=cut

use Pelement;
use PelementCGI;
use Session;

use CGI::FormBuilder;
use CGI::Session qw/-ip-match/;

use strict;

my $cgi = new PelementCGI;

my $s = new Session({-log_level=>0});
CGI::Session->name("PELEMENTSID");
my $cgiSession = new CGI::Session("driver:PostgreSQL", $cgi, {Handle=>$s->db});


my $msg;
if (my $id = $cgiSession->param('user_id')) {
  $cgiSession->delete or $msg = $cgiSession->error;
  print $cgi->header();
  unless ($msg) {
    print $cgi->init_page({-title=>'Logout Successful',
                       -style=>{-src=>'/pelement/pelement.css'},
         -head=>["<META HTTP-EQUIV=\"refresh\" content=\"2; URL=pelement.pl\"/>"]});
    print $cgi->banner();
    print $cgi->p($cgi->em("You were logged in as ",$cgi->b($id))),
          $cgi->hr,"\n";
    print $cgi->p("Good bye, $id\n",$cgi->br,
                   'Your browser should return to the main page, or ',
                    $cgi->a({-href=>'pelement.pl'},'click'),' to continue.');
  } else {
    print $cgi->init_page({-title=>'Logout Unsuccessful',
                       -style=>{-src=>'/pelement/pelement.css'},
         -head=>["<META HTTP-EQUIV=\"refresh\" content=\"2; URL=pelement.pl\"/>"]});
    print $cgi->banner();
    print $cgi->p($cgi->em("You were logged in as ",$cgi->b($id))),
          $cgi->hr,"\n";
    print $cgi->p("There was an error when logging out: $msg."),
          $cgi->p("Use your browser to remove the cookie PELEMENTSID for a guaranteed logout.")
  }

} else {

  print $cgi->header();
  print $cgi->init_page({-title=>'Logout Unsuccessful',
                       -style=>{-src=>'/pelement/pelement.css'},
      -head=>
           ["<META HTTP-EQUIV=\"refresh\" content=\"2; URL=pelement.pl\"/>"]});
  print $cgi->banner();
  print $cgi->p("There is no record of your user id.");
}
  
print $cgi->footer([
                 {link=>"batchReport.pl",name=>"Batch Report"},
                 {link=>"strainReport.pl",name=>"Strain Report"},
                 {link=>"gelReport.pl",name=>"Gel Report"},
                 {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                  ]);

print $cgi->close_page();

$s->exit;
exit(0);
