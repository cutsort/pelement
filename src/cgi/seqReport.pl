#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqReport.pl Web report of the batch processing information.

=cut

use Pelement;
use Session;
use Phred_Seq;
use Lane;
use LaneSet;
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

   # if passed a strain identifier, look for the lanes with sequence that match this
   my @tableRows = ();
   if ($cgi->param('strain') ) {
      my $session = new Session({-log_level=>0});
      my $str = $cgi->param('strain')."%";
      my $laneSet = new LaneSet($session,{-like=>{'seq_name'=>$str}})->select();
      map { push @tableRows, [$_->seq_name || 'Unknown' ,$_->end_sequenced || 'Unknown' ,$_->run_date || 'Unknown' ,
                              $cgi->a({-href=>"seqReport.pl?id=".$_->id},$_->id)] } $laneSet->as_list;

      if (@tableRows) {
                          
         print $cgi->center($cgi->table({-border=>2,
                                   -width=>"80%",
                                   -bordercolor=>$HTML_TABLE_BORDERCOLOR},
            $cgi->Tr( [
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'10%'},
                      ["Sequence".$cgi->br."Name"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                      ["End"]).
               $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'15%'},
                      ["Date","Id"]),
                      (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";
      } else {
          print $cgi->h3("No lanes were found for strain ".$cgi->param('strain')),"\n";
      }
      $session->exit;
            
      
   } else {
   
      print
        $cgi->center(
          $cgi->h3("Enter the Lane id:"),"\n",
          $cgi->br,
          $cgi->start_form(-method=>"get",-action=>"seqReport.pl"),"\n",
             $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
                $cgi->Tr( [
                   $cgi->td({-align=>"right",-align=>"left"},
                                       ["Lane ID",$cgi->textfield(-name=>"id")]),
                 $cgi->td({-align=>"right",-align=>"left"},
                       [$cgi->em('or').' Strain',$cgi->textfield(-name=>"strain")]),
                   $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                   $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
                ),"\n",
             ),"\n",
          $cgi->end_form(),"\n",
          ),"\n";
   }
}

sub reportSeq
{
   my $cgi = shift;

   my $session = new Session({-log_level=>0});

   my $seq;
   my $lane;

   # from which table is this id referring to? the lane table or
   # the phred seq table?
   my $table = $cgi->param('db') || 'lane';

   if ($cgi->param('id') ) {
      if ($table eq 'lane') {
         $lane = new Lane($session,{-id=>$cgi->param('id')});
         $seq = new Phred_Seq($session,{-lane_id=>$cgi->param('id')});
      } elsif ($table eq 'phred_seq') {
         $seq = new Phred_Seq($session,{-id=>$cgi->param('id')});
         $seq->select_if_exists;
         $lane = new Lane($session,{-id=>$seq->lane_id}) if $seq->lane_id;
      }
   }

   if ( !$lane->db_exists | !$seq->db_exists ) {
      print $cgi->center($cgi->h2("No record for Sequence with Lane id ".
                                   $seq->lane_id.".")),"\n";
      return;
   }

   $lane->select;
   $seq->select;

   my $sequence = uc($seq->seq);
   my $trimmed_sequence;


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
    my $trimmed_seq_title = $lane->seq_name."-".$lane->end_sequenced." trimmed";
    print ">$seq_title\n";

    print "<font color='blue'>\n";
    my $mode = 'tt';

    foreach $i (0..length($sequence)-1) {
       print "<br>\n" unless $i % 50;
       if ($mode eq 'tt' && (
           ($seq->v_trim_start && $i < $seq->v_trim_start ) ||
           ($seq->v_trim_end   && $i >= $seq->v_trim_end ) ||
           ($seq->q_trim_end   && $i >= $seq->q_trim_end ) ) ) {
          $mode = 'it';
          print "</font><font color='red'>";
       } elsif ($mode eq 'it' && (
           ($seq->v_trim_start && $i >= $seq->v_trim_start ) &&
           (!$seq->v_trim_end  || $i < $seq->v_trim_end )    &&
           ($seq->q_trim_end   && $i < $seq->q_trim_end ) ) ) {
         $mode = 'tt';
         print "</font><font color='blue'>";
      }
      print substr($sequence,$i,1);
      $trimmed_sequence .= substr($sequence,$i,1) if $mode eq 'tt' and substr($sequence,$i,1) =~ /[A-Z]/;
   }
   print "</font>" if $mode eq 'it';
   print "</tt>\n";


   print $cgi->br,"\n";

   print $cgi->em('Key:'),"\n",
         $cgi->ul($cgi->li(["<font color='red'>Vector</font>",
                            "<font color='blue'>Flank</font>",
                            "UPPER CASE: HIGH QUALITY",
                            "lower case: low quality",])),"\n";
   # we need to unescape the action setting to keep the 'http://'in the URL
   print $cgi->center(
            $cgi->unescape($cgi->start_form(-method=>'post',
                             -action=>"http://www.fruitfly.org/cgi-bin/blast/public_blaster.pl",
                             -target=>'_flyblast')),"\n",
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
               $cgi->submit(-name=>'Blast Entire Sequence'),"\n",
            $cgi->end_form(),
            $cgi->unescape($cgi->start_form(-method=>'post',
                             -action=>"http://www.fruitfly.org/cgi-bin/blast/public_blaster.pl",
                             -target=>'_flyblast')),"\n",
               $cgi->hidden(-name=>'program',-value=>'blastn'),"\n",
               $cgi->hidden(-name=>'program',-value=>'blastn'),"\n",
               $cgi->hidden(-name=>'database',-value=>'na_all.dros'),"\n",
               $cgi->hidden(-name=>'title',-value=>$trimmed_seq_title),"\n",
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
               $cgi->hidden(-name=>'sequence',-value=>$trimmed_sequence),"\n",
               $cgi->submit(-name=>'Blast Trimmed Sequence'),"\n",
            $cgi->end_form()
          ),"\n";

   $session->exit();
}
