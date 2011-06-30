#!/usr/local/bin/perl -I../modules

=head1 NAME

  digRegister.pl Web registration of digestions.

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

my $user_id;
if (!($user_id=$cgiSession->param('user_id')) ) {
  $cgiSession->save_param($cgi);
  $cgiSession->param('referrer','digRegister.pl');
  print $cgi->redirect(-cookie=>$cookie,-uri=>"login.pl");
} elsif ($cgiSession->param('restore_param')) {
  $cgiSession->load_param($cgi);
}

print $cgi->header( -cookie => $cookie );
print $cgi->init_page({-title=>"Digestion Registration",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();

my $form = new CGI::FormBuilder(
           header => 0,
           method => 'POST',
           reset  => 'Clear',
           validate => { 'batch' => 'NUM',
                         'enzyme1' => 'VALUE',
                         'enzyme2' => 'VALUE',
                       },
           );

my $enzymes = $s->EnzymeSet()->select;
my $batch_todo = $s->Digestion_To_DoSet()->select;

unless ($enzymes && $batch_todo) {
  print $cgi->h3("There was a problem connecting to the db.");
  $s->die;
}


my @enzymes;
map { push @enzymes, $_->enzyme_name } $enzymes->as_list;

my @batch_todo;
map { push @batch_todo, $_->batch } $batch_todo->as_list;

$form->field(name=>'batch',options=>\@batch_todo,label=>'Batch Number');
$form->field(name=>'enzyme1',options=>\@enzymes,label=>'3\' Enzyme');
$form->field(name=>'enzyme2',options=>\@enzymes,label=>'5\' Enzyme');

if ($form->submitted && $form->validate) {

    my $batch = $form->field('batch');
    my $enzyme1 = $form->field('enzyme1');
    my $enzyme2 = $form->field('enzyme2');

    # at some point we're going to have to figure out how to do rework.
    my $dig = $s->Digestion({-name=>$batch.'.D1',
                             -batch_id => $batch,
                             -enzyme1  => $enzyme1,
                             -enzyme2  => $enzyme2,
                             -user_login => $user_id,
                             -digestion_date => 'today'});
    # insert it
    $dig->insert;

    unless ($dig->id) {
      print $cgi->p($cgi->em("There was some trouble inserting this record."));
    } else {
      print $cgi->p($cgi->em('Digestion record for batch ',
                    $cgi->a({-href=>'batchReport.pl?batch='.$batch},$batch),
                    ' inserted.'));
    }

} elsif ( scalar(@batch_todo) == 0 ) {

    print $cgi->center($cgi->b("There are no batches ready for digestion."));

} else {

    print $cgi->p($cgi->em('You are currently logged in as ',$cgi->b($user_id),'. '),
          $cgi->a({-href=>'logout.pl'},'Logout')),
          $cgi->center($cgi->hr,
                       $form->render(submit=>['Enter']));
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

