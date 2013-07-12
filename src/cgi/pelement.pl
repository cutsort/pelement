#!/usr/bin/env perl
use FindBin::libs 'base=modules';


=head1 Name

  pelement.pl The main entry page for pelement processing

=head1 Description

  Pretty much a static page, but we can use this is a login/logout portal

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

my $cookie = $cgi->cookie(PELEMENTSID => $cgiSession->id);

print $cgi->header(-cookie => $cookie);
print $cgi->init_page({-title=>"P Element Portal",
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner;

if (my $id = $cgiSession->param('user_id')) {
  print $cgi->p($cgi->em("You are currently logged in as ",$cgi->b($id)),
        $cgi->a({-href=>'logout.pl'},'Logout'));
} else {
  $cgiSession->param('referrer','pelement.pl');
  print $cgi->p($cgi->em("You are not currently logged in. "),
        $cgi->a({-href=>'login.pl'},'Login'));
}
  

print $cgi->center( $cgi->table({-width=>'70%',
                                 -class=>'unboxed'},
                            $cgi->th({-background-color=>'gray',
                                      -class=>'unboxed'},['Registration','Report']),
                              $cgi->Tr( [
                                      $cgi->td({-class=>'unboxed'},[
                                        $cgi->table({-width=>'80%',-class=>'unboxed'},
                                         $cgi->Tr( [
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'batchRegister.pl'},'Batch Registration')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'digRegister.pl'},'Digestion Registration')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'ligRegister.pl'},'Ligation Registration')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'ipcrRegister.pl'},'iPCR Registration')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'seqRegister.pl'},'Sequencing Registration') ] ),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'sampleSheet.pl'},'(Re)Generate Sample Sheet') ] ) ] ) ),
                                      $cgi->table({-width=>'80%',-class=>'unboxed'},
                                       $cgi->Tr( [
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'batchReport.pl'},'Batch Report')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'strainReport.pl'},'Strain Report')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'gelReport.pl'},'Gel Report')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'setReport.pl'},'Set Report')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'recentBatches.pl'},'Recently Registed Batches')]),
                                         $cgi->td({-class=>'unboxed'},[
                                           $cgi->a({-href=>'todoList.pl'},'Production To-Do List')]),
                                         ] ) )
                                 ]  )
                             ] ))),"\n";

print $cgi->footer();
print $cgi->close_page();

$s->exit;

exit(0);
