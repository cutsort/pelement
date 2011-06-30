#!/usr/local/bin/perl -I../modules

=head1 NAME

  strainStatusReport.pl Web report of the batch processing information.

=cut

use Pelement;
use Session;
use Strain;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>$cgi->param('strain')." Strain Status Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();


if ($cgi->param('strain')) {
   if ($cgi->param('update')) {
      updateStatus($cgi);
   } else {
      reportStrain($cgi);
   }
} else {
   selectStrain($cgi);
}

print $cgi->footer();
print $cgi->close_page();

exit(0);


sub selectStrain
{

   my $cgi = shift;
  
   print
     $cgi->center(
       $cgi->h3("Enter the Strain name:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"strainStatusReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["Strain Name",$cgi->textfield(-name=>"strain")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub reportStrain
{
   my $cgi = shift;

   my $session = shift || new Session({-log_level=>0});

   my $strain_name = $cgi->param('strain');
   # clean up
   $strain_name =~ s/\s+//g;
   $strain_name =~ s/-[35]$//;
   $strain = new Strain($session,{-strain_name=>$strain_name});

   if ($strain->db_exists) {
      $strain->select;
      print $cgi->center(
              $cgi->p("The strain ".
                      $cgi->a({-href=>"strainReport.pl?strain=".$strain_name},$strain_name).
                      " was registered ".$strain->registry_date.
                      " and currently has status ".$cgi->b($strain->status)),"\n",
                 $cgi->start_form(-method=>"get",-action=>"strainStatusReport.pl"),"\n",
                 $cgi->hidden(-name=>'strain',-value=>$strain_name),
                 $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
                    $cgi->Tr( [ 
                       $cgi->th({-colspan=>2},"Update status for $strain_name"),
                       $cgi->td({-align=>"center"},
                           ['(Re)declare status '.$cgi->em('new'),
                            $cgi->submit(-name=>"update",-value=>'New')]),
                       $cgi->td({-align=>"center"},
                           ['Declare the status '.$cgi->em('permanent'),
                            $cgi->submit(-name=>"update",-value=>'Permanent')]),
                       $cgi->td({-align=>"center"},
                           ['Declare the status '.$cgi->em('discard'),
                            $cgi->submit(-name=>"update",-value=>'Discard')]) ]
                    ),"\n",                          
                 ),"\n",
                 $cgi->end_form(),"\n",
              ),"\n";

   } else {
      print $cgi->center($cgi->em("There is no record for strain $strain_name in the database.")),"\n";
   }
   $session->exit();
}

sub updateStatus
{
   my $cgi = shift;
   my $session = new Session({-log_level=>0});

   my $strain_name = $cgi->param('strain');
   # clean up
   $strain_name =~ s/\s+//g;
   $strain_name =~ s/-[35]$//;
   $strain = new Strain($session,{-strain_name=>$strain_name});

   if ($strain->db_exists) {
      $strain->select;
      
      my $new_status = lc($cgi->param('update'));
      
      if ($new_status eq 'new' || $new_status eq 'discard' || $new_status eq 'permanent')  {
         $strain->status($new_status);
         $strain->update('strain_name');
      }
   }
   reportStrain($cgi,$session);
}

