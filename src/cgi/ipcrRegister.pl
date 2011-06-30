#!/usr/local/bin/perl -I../modules

=head1 NAME

  ipcrRegister.pl Web registration of iPCR.

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

my $id;
if (!($id =$cgiSession->param('user_id')) ) {
  $cgiSession->save_param($cgi);
  $cgiSession->param('referrer','digRegister.pl');
  print $cgi->redirect(-cookie=>$cookie,-uri=>"login.pl");
} elsif ($cgiSession->param('restore_param')) {
  $cgiSession->load_param($cgi);
}

print $cgi->header( -cookie => $cookie );
print $cgi->init_page({-title=>"iPCR Registration",
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

my $primers = $s->PrimerSet()->select;
my $ipcr_todo = $s->Ipcr_To_DoSet()->select;

unless ($primers && $ipcr_todo) {
  print $cgi->h3("There was a problem connecting to the db.");
  $s->die;
}


my @primersF;
my @primersR;
map { push @primersF, $_->name if $_->direction eq 'f' || $_->direction eq 'b'}
                                                             $primers->as_list;
map { push @primersR, $_->name if $_->direction eq 'r' || $_->direction eq 'b'}
                                                             $primers->as_list;

@primersF = sort @primersF;
@primersR = sort @primersR;

my @ipcr_todo;
map { push @ipcr_todo, $_->name.':'.$_->end_type }
           sort { $b->ligation_date cmp $a->ligation_date } $ipcr_todo->as_list;


$form->field(name=>'ligation',options=>\@ipcr_todo,label=>'Ligation Id');
$form->field(name=>'primer1',options=>\@primersF,label=>'Forward Primer');
$form->field(name=>'primer2',options=>\@primersR,label=>'Reverse Primer');

if ($form->submitted && $form->validate &&
    $form->field('primer1') && $form->field('primer2') && $form->field('ligation') ){

    my $ligation = $form->field('ligation');

    # this should be a ligation and end type.
    my ($lig,$end) = split(/:/,$ligation);
    unless ($lig && $end) {
      print $cgi->p($cgi->em("Cannot understand the parameters $ligation."));
    } else {
      # which P?
      my $iSet = $s->IpcrSet({-like=>{name=>$lig.'%'}})->select;
      my $ctr = $iSet->count + 1;
      my $ipcr = $s->Ipcr({-name=>$lig.'.P'.$ctr,
                               -ligation_name => $lig,
                               -primer1 => $form->field('primer1'),
                               -primer2 => $form->field('primer2'),
                               -end_type => $end,
                               -user_login => $id,
                               -ipcr_date => 'today'});
      # insert it
      $ipcr->insert;
  
      unless ($ipcr->id) {
        print $cgi->p($cgi->em("There was some trouble inserting this record."));
      } else {
        (my $batch = $lig) =~ s/^(\d+)\..*/$1/;
        print $cgi->p($cgi->em('iPCR record for batch ',
                    $cgi->a({-href=>'batchReport.pl?batch='.$batch},$batch),
                    ' inserted.'));
      }
    }

} elsif ( scalar(@ipcr_todo) == 0 ) {

  print $cgi->center($cgi->b("There are no batches ready for iPCR."));

} else {

    print $cgi->p($cgi->em('You are currently logged in as ',$cgi->b($id),'. '),
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

