#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqReport.pl Web report of the batch processing information.

=cut

use Pelement;
use Session;
use Phred_Seq;
use Lane;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page();
print $cgi->banner();


if ($cgi->param('id')) {
   reportSeq($cgi);
} else {
   selectSeq($cgi);
}

print $cgi->footer();
print $cgi->close_page();

exit(0);


sub selectSeq
{

   my $cgi = shift;
  
   print
     $cgi->center(
       $cgi->h3("Enter the Lane id:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"seqReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["Lane ID",$cgi->textfield(-name=>"name")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub reportSeq
{
   my $cgi = shift;

   my $session = new Session({-log_level=>0});

   my $seq;
   my $lane;
   if ($cgi->param('id') ) {
      $lane = new Lane($session,{-id=>$cgi->param('id')});
      $seq = new Phred_Seq($session,{-lane_id=>$cgi->param('id')});
   }

   if ( !$lane->db_exists | !$seq->db_exists ) {
      print $cgi->center($cgi->h2("No record for Sequence with Lane id ".
                                   $seq->lane_id.".")),"\n";
      return;
   }

   $lane->select;
   $seq->select;

   my $sequence = uc($seq->seq);


   if($seq->q_trim_start) {
      $sequence = lc(substr($sequence,0,$seq->q_trim_start)).
                     substr($sequence,$seq->q_trim_start);
   }

    if($seq->q_trim_end) {
       $sequence = substr($sequence,0,$seq->q_trim_end).
                   lc(substr($sequence,$seq->q_trim_end));
    }

    print "<tt>";
    my $seq_title = $lane->seq_name."-".$lane->end_sequenced." untrimmed";
    print ">$seq_title\n";

    print "<font color='blue'>\n";
    my $mode = 'tt';

    foreach $i (0..length($sequence)-1) {
       print "<br>\n" unless $i % 50;
       if ($mode eq 'tt' && (
           ($seq->v_trim_start && $i < $seq->v_trim_start ) ||
           ($seq->v_trim_end   && $i >= $seq->v_trim_end ) ) ) {
          $mode = 'it';
          print "</font><font color='red'>";
       } elsif ($mode eq 'it' && (
           ($seq->v_trim_start && $i >= $seq->v_trim_start ) &&
           ($seq->v_trim_end   && $i < $seq->v_trim_end ) ) ) {
         $mode = 'tt';
         print "</font><font color='blue'>";
      }
      print substr($sequence,$i,1);
   }
   print "</font>" if $mode eq 'it';
   print "</tt>\n";


   print $cgi->br,"\n";

   print $cgi->em('Key:'),"\n",
         $cgi->ul($cgi->li(["<font color='red'>Vector</font>",
                            "<font color='blue'>Flank</font>",
                            "UPPER CASE: HIGH QUALITY",
                            "lower case: low quality",])),"\n";
   print $cgi->center(
            $cgi->start_form(-method=>'post',
                             -action=>'http://www.fruitfly.org/cgi-bin/blast/public_blaster.pl',
                             -target=>'_flyblast'),"\n",
               $cgi->hidden(-name=>'program',-value=>'blastn'),"\n",
               $cgi->hidden(-name=>'program',-value=>'blastn'),"\n",
               $cgi->hidden(-name=>'database',-value=>'na_all.dros'),"\n",
               $cgi->hidden(-name=>'title',-value=>$seq_title),"\n",
               $cgi->hidden(-name=>'submit',-value=>'doblast'),"\n",
               $cgi->hidden(-name=>'mail',-value=>'browser'),"\n",
               $cgi->hidden(-name=>'histogram',-value=>'no'),"\n",
               $cgi->hidden(-name=>'nscores',-value=>'100'),"\n",
               $cgi->hidden(-name=>'nalign',-value=>'50'),"\n",
               $cgi->hidden(-name=>'sort_by',-value=>'pvalue'),"\n",
               $cgi->hidden(-name=>'matrix',-value=>'IDENTITY'),"\n",
               $cgi->hidden(-name=>'expthr',-value=>'default'),"\n",
               $cgi->hidden(-name=>'cutoff',-value=>'default'),"\n",
               $cgi->hidden(-name=>'stats',-value=>'poisson'),"\n",
               $cgi->hidden(-name=>'filter',-value=>'All'),"\n",
               $cgi->hidden(-name=>'strand',-value=>'both'),"\n",
               $cgi->hidden(-name=>'dbstrand',-value=>'both'),"\n",
               $cgi->hidden(-name=>'sequence',-value=>$sequence),"\n",
               $cgi->submit(-name=>'Blast This Sequence'),"\n",
            $cgi->end_form()
          ),"\n";

   $session->exit();
}
