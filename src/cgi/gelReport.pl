#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  gelReport.pl Web report of the gel processing information.

=cut

use Pelement;
use Session;
use Gel;
use LaneSet;
use Phred_Seq;
use PelementCGI;
use PelementDBI;
use Processing;

$cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>"Gel Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();


if ($cgi->param('id') || $cgi->param('name')) {
   reportGel($cgi);
} else {
   selectGel($cgi);
}

print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                    ]);
print $cgi->close_page();

exit(0);


sub selectGel
{

   my $cgi = shift;
  
   print
     $cgi->center(
       $cgi->h3("Enter the Gel Name:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"gelReport.pl"),"\n",
          $cgi->table( {-class=>'unboxed'},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                  ["Gel Name",$cgi->textfield(-name=>"name")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                  [$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                  [$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub reportGel
{
   my $cgi = shift;

   my $session = new Session({-log_level=>0});

   my $gel;
   if ($cgi->param('id') ) {
      $gel = new Gel($session,{-id=>$cgi->param('id')});
   } else {
      $gel = new Gel($session,{-name=>$cgi->param('name')});
   }

   if ( !$gel->db_exists ) {
      print $cgi->center($cgi->h2("No record for Gel ".
                               ($gel->id || $gel->name).".")),"\n";
      return;
   }

   $gel->select;

   # what sort of meta info do we have on this:
   if ( my $batch = Processing::batch_id($gel->ipcr_name) ) {
      print $cgi->center($cgi->em($gel->name." is from batch "),
                         $cgi->a({-href=>"batchReport.pl?batch=$batch"},$batch),
                         $cgi->em(", and was registered ".$gel->gel_date.".")),$cgi->br,"\n";
   }


   my @tableRows = ();
   my $laneSet = new LaneSet($session,{-gel_id=>$gel->id})->select;
   foreach my $s ($laneSet->as_list) {
      my $p = new Phred_Seq($session,{-lane_id=>$s->id})->select_if_exists;
      push @tableRows, [$s->seq_name?$cgi->a({-href=>"strainReport.pl?strain=".$s->seq_name},$s->seq_name):'Unknown',
                        $s->well || $cgi->nbsp,
                        $s->run_date || 'Unknown',
                        $s->id?$cgi->a({-href=>"seqReport.pl?id=".$s->id,-target=>"_seq"},
                                       length($p->seq)):$cgi->nbsp,
                        $s->id?$cgi->a({-href=>"chromatReport.pl?id=".$s->id,-target=>"_chromat"},
                                       $p->q30 ."/". $p->q20):$cgi->nbsp,
                        $p->q_trim_start || $cgi->nbsp,
                        $p->v_trim_start || $cgi->nbsp,
                        $p->v_trim_end || $cgi->nbsp,
                        $p->q_trim_end || $cgi->nbsp,
                        ];
   }


   @tableRows = sort { my ($ar,$ac) = ($a->[1]=~/(.)(\d+)/);
                       my ($br,$bc) = ($b->[1]=~/(.)(\d+)/);
                       (uc($ar) cmp uc($br)) || ($ac <=> $bc) || $a->[2] cmp $b->[2] } @tableRows;

   print $cgi->center($cgi->h3("Lanes For Gel ".$gel->name),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,
                                    -width=>"80%",
                              -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain","Well","Run Date","Phred".$cgi->br."Sequence".$cgi->br."Length",
                       "q30/q20",
                       "Quality".$cgi->br."Start",
                       "Flanking".$cgi->br."Seq".$cgi->br."Start",
                       "Restriction".$cgi->br."Site",
                       "Quality".$cgi->br."End",]),
                        (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] )
                     )),"\n",
         $cgi->br,"\n",
         $cgi->html_only($cgi->a({-href=>"gelReport.pl?format=text&id=".$gel->id},
                  "View as Tab delimited list"),$cgi->br,"\n");

  $session->exit();
}
