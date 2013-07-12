#!/usr/bin/env perl
use FindBin::libs 'base=modules';

=head1 NAME

  ligRegister.pl Web registration of ligations.

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
if (!($user_id =$cgiSession->param('user_id')) ) {
  $cgiSession->save_param($cgi);
  $cgiSession->param('referrer','ligRegister.pl');
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
my $lig_todo = $s->Ligation_To_DoSet()->select;

unless ($enzymes && $lig_todo) {
  print $cgi->h3("There was a problem connecting to the db.");
  $s->die;
}


my @enzymes;
map { push @enzymes, $_->enzyme_name } $enzymes->as_list;

my @lig_todo;
map { push @lig_todo, $_->name } $lig_todo->as_list;


$form->field(name=>'digestion',options=>\@lig_todo,label=>'Digestion Id');

if ($form->submitted && $form->validate) {

    my $digestion = $form->field('digestion');

    # deal with rework later
    my $lig = $s->Ligation({ -name=>$digestion.'.L1',
                             -digestion_name => $digestion,
                             -user_login => $user_id,
                             -ligation_date => 'today'});
    # insert it
    $lig->insert;

    ## remember to change this
    unless ($lig->id) {
      print $cgi->p($cgi->em("There was some trouble inserting this record."));
    } else {
      (my $batch = $digestion) =~ s/^(\d+)\..*/$1/;
      print $cgi->p($cgi->em('Ligation record for batch ',
                    $cgi->a({-href=>'batchReport.pl?batch='.$batch},$batch),
                    ' inserted.'));
    }

} elsif ( scalar(@lig_todo) == 0 ) {

  print $cgi->center($cgi->b("There are no batches ready for Ligation."));

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

