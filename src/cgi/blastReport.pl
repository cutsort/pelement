#!/usr/local/bin/perl -I../modules

=head1 NAME

  blastReport.pl Web report of the blast HSP information

=cut

use Pelement;
use PelementCGI;
use Session;
use PelementDBI;
use Blast_Report;


$cgi = new PelementCGI;
my $hsp_id = $cgi->param('id');
my $orient = $cgi->param('orient') || '1';

print $cgi->header;
print $cgi->init_page({-title=>"Blast Report"});
print $cgi->banner;


if ($hsp_id) {
   reportHSP($cgi,$hsp_id,$orient);
} else {
   selectHSP($cgi);
}

print $cgi->footer;
print $cgi->close_page;

exit(0);


sub selectHSP
{

  my $cgi = shift;
  
  print
    $cgi->center(
       $cgi->h3("Enter the Blast HSP Identifier:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",
                          -action=>"/cgi-bin/pelement/blastReport.pl"),"\n",
          $cgi->table(
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["ID:",$cgi->textfield(-name=>"id")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                    [$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                    [$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
    ),"\n";
}

sub reportHSP
{
   my $cgi = shift;
   my $id = shift;
   my $orient = shift || 1;

   my $session = new Session({-log_level=>0});
   my @values = ();
   my $bR = new Blast_Report($session,{-id=>$id});

   unless ($bR->db_exists) {
      print $cgi->center($cgi->h3("No record found for hit $id."));
   } else {

     $bR->select;

     print $cgi->center(
           $cgi->h3("Blast Hit for sequence ",$bR->seq_name),$cgi->br),"\n",
           $bR->to_html($cgi,$orient);


     $orient = -1*$orient;
     print $cgi->center($cgi->a({-href=>"blastReport.pl?id=$id&orient=$orient"},
           "Reverse Complement")),"\n";

   }
   $session->exit();
}
