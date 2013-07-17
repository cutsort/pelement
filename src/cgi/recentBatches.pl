#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);


=head1 Name

recentBatches.pl The summary page recent batches

=head1 Description

Print a page with batches done in the last 2 weeks (configurable?)
with links
  

=cut

use Pelement;
use PelementCGI;
use Session;
use BatchSet;

use CGI::FormBuilder;

use strict;

my $cgi = new PelementCGI;

my $s = new Session({-log_level=>0});

print $cgi->header;
print $cgi->init_page({-title=>"P Element Batch Summary",
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner;

my $days = $cgi->param('day') || 30;
my $one_month_ago = PCommon::time_value(time()-$days*24*60*60);
my $batch = new BatchSet($s,{-greater_than_or_equal=>
              {batch_date=>$one_month_ago}})->select;

if ( $batch->count ) {

my @contents = ();
map { push @contents, [ $cgi->a({-href=>'batchReport.pl?batch='.$_->id},'Batch '.$_->id), $_->batch_date ] }
           sort { $b->batch_date cmp $a->batch_date } $batch->as_list;

print $cgi->center( "There are ".$batch->count." recent batches.",
                    $cgi->br,
                    $cgi->table({-width=>'70%',
                                 -class=>'unboxed'},
                            $cgi->Tr( [
                            $cgi->th({-background-color=>'gray',
                                      -class=>'unboxed'},['Batch','Registration Date']),
                              ( map { $cgi->td({-class=>'unboxed'},$_)} @contents )]
                              ))),"\n";


} else {
  print $cgi->center("There are no recent batches.");
}
print $cgi->footer();
print $cgi->close_page();

$s->exit;

exit(0);
