#!/usr/local/bin/perl -I../modules

=head1 NAME

  sampleSheet.pl Web registration of sequencing reactions.

=cut

use Pelement;
use PelementCGI;
use Session;
use SampleSet;

use CGI::FormBuilder;
use CGI::Session qw/-ip-match/;

use strict;

my $cgi = new PelementCGI;
my $s = new Session({-log_level=>0});


# defer writing the header until we see what we got.
my $form = new CGI::FormBuilder(
           header => 0,
           method => 'POST',
           reset  => 'Clear',
           validate => { 'gel' => 'VALUE',
                       },
           );

$form->field(name=>'gel',label=>'Gel Name');



if ($form->submitted && $form->validate) {

    my $gel = $form->field('gel');
    my $g = $s->Gel({-name => $gel})->select_if_exists;

    unless ($g->id) {
      ##print $cgi->p($cgi->em("There is no such gel."));
    } else {
      print $cgi->header(-type=>'text/plain',);
                   ##-content_disposition=>'attachment; filename=sample.plt');
      print $g->sample_sheet;
      $s->exit;
      exit(0);
    }

} else {

    print $cgi->header;
    print $cgi->init_page({-title=>"Sequencing Sample Sheets"});
    print $cgi->banner();
    print $cgi->center($cgi->hr,
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
