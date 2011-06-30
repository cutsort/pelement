#!/usr/local/bin/perl -I../modules

=head1 NAME

  login.pl Web user_id setter

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

my $form = new CGI::FormBuilder(
           fields => [qw(name)],
           header => 0,
           method => 'GET',
           );

if (my $id = $cgiSession->param('user_id')) {
  print $cgi->p($cgi->em("You are currently logged in as ",$cgi->b($id)),
        $cgi->a({-href=>'logout.pl'},'Logout')),
        $cgi->hr,"\n";
}

if ($form->submitted && $form->validate && (my $id = $form->param('name') ) ) {

  # see if this is a real person
  # we should have checked at $id is not null at
  # the validate stage, but check again
  if ($id && $s->Person({-login=>$id})->db_exists ) {
    # set the user id field for this session
    $cgiSession->param('user_id',$id);

    my $back_url = $cgiSession->param('referrer');
    if ($back_url) {
      print $cgi->header();
      print $cgi->init_page({-title=>'Login Successful',
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'},
          -head=>
           ["<META HTTP-EQUIV=\"refresh\" content=\"2; URL=$back_url\"/>"]});
      print $cgi->banner();
      print $cgi->p("Hello, $id\n",$cgi->br,
                   'Your browser should return to the previous form, or ',
                    $cgi->a({-href=>$back_url},'click'),' to continue.');
    } else {
      print $cgi->header();
      print $cgi->init_page({-title=>"Login Successful",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
      print $cgi->banner();
      print $cgi->p("Hello, $id\n",$cgi->br,
        "Your login was successful, but there is no referring URL for return.");
    }
  } else {
    print $cgi->header;
    print $cgi->init_page({-title=>"Login Unsuccessful",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
    print $cgi->banner;
    print $cgi->p("Your login name could not be found in the db.");
    print $cgi->center($form->render);
  }

} else {

  print $cgi->header();
  print $cgi->init_page({-title=>"Login",
                         -script=>{-src=>'/pelement/sorttable.js'},
                         -style=>{-src=>'/pelement/pelement.css'}});
  print $cgi->banner();
  print $cgi->center(
        $cgi->h3("Authentification Required."),
        $cgi->em("Please enter your login name for access to these pages."));
  print $cgi->center($form->render);
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
