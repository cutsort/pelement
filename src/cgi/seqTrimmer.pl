#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqTrimmer.pl Web interface for manual Sequence trimming

=cut

use Pelement;
use Session;
use Phred_Seq;
use Seq;
use Lane;
use LaneSet;
use PelementCGI;
use PelementDBI;

use GH::Sim4;

$cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>"Manual Sequence Trimming",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();


if ($cgi->param('id')) {
   trimSeq($cgi);
   print $cgi->a({-href=>'seqReport.pl?db=lane&id='.$cgi->param('id')},
                 "Return to Sequence Report"),$cgi->br,"\n";
} else {
   selectSeq($cgi);
}

print $cgi->footer();
print $cgi->close_page();

exit(0);

sub selectSeq
{

   my $cgi = shift;

   # if passed a strain identifier, look for the lanes with
   #sequence that match this
   my @tableRows = ();
   if ($cgi->param('strain') ) {
      my $session = new Session({-log_level=>0});
      my $str = $cgi->param('strain')."%";
      my $laneSet = new LaneSet($session,{-like=>{'seq_name'=>$str}})->select();
      map { push @tableRows, [$_->seq_name || 'Unknown' ,
                         $_->end_sequenced || 'Unknown' ,
                              $_->run_date || 'Unknown' ,
                $cgi->a({-href=>"seqTrimmer.pl?id=".$_->id},$_->id)] }
                                                         $laneSet->as_list;

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
          print $cgi->h3("No lanes were found for strain ".
                                         $cgi->param('strain')),"\n";
      }
      $session->exit;


   } else {

      print
        $cgi->center(
          $cgi->h3("Enter the Lane id:"),"\n",
          $cgi->br,
          $cgi->start_form(-method=>"get",-action=>"seqTrimme.pl"),"\n",
             $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
                $cgi->Tr( [
                   $cgi->td({-align=>"right",-align=>"left"},
                                   ["Lane ID",
                                         $cgi->textfield(-name=>"id")]),
                 $cgi->td({-align=>"right",-align=>"left"},
                        [$cgi->em('or').' Strain',
                                         $cgi->textfield(-name=>"strain")]),
                   $cgi->td({-colspan=>2,-align=>"center"},
                                         [$cgi->submit(-name=>"Select")]),
                   $cgi->td({-colspan=>2,-align=>"center"},
                                         [$cgi->reset(-name=>"Clear")]) ]
                ),"\n",
             ),"\n",
          $cgi->end_form(),"\n",
          ),"\n";
   }
}

sub trimSeq
{

   my $cgi = shift;

   if ($cgi->param('seq') ) {
     processTrimmedSeq($cgi);
   } else {

      print $cgi->p(qq(Directions: <br>
                       Delete and reinsert the '>' character at the new
                       location of the vector insert junction to indicate
                       the vector trimming locations.<br>
                       Delete and reinsert the '<' character at the new
                       location of the restriction site to indicate the
                       flanking sequence extent.<br>
                       Insert a '!' character prior to the first high quality
                       base to indicate any change in the start of the high
                       quality sequence.<br>
                       Insert a '.' character after to the last high quality
                       base to indicate any change in the end of the high
                       quality sequence.<br>
                       The existing locations for the vector-insert junctions
                       and restriction sites are shown by '>' and '<'.<br>
                       High quality regions are indicated by capital letters.)),
            $cgi->em(qq(At the present time editing the base calls is not
                       allowed.)),$cgi->br;

      # get the sequence.
      
      my $session = new Session({-log_level=>0});
      #my $lane = new Lane($session,{-id=>$cgi->param('id')})->select_if_exists;
      
      my $seq = new Phred_Seq($session,{-lane_id=>$cgi->param('id')})->select_if_exists;

      my $bases = $seq->seq;
      # assume low quality
      $bases =~ tr/ACGTN/acgtn/;
      # and uppercase the high quality bases


      # I need to check all of these to see how many are off by 1.
      if ($seq->q_trim_start && $seq->q_trim_end &&
                                  $seq->q_trim_end > $seq->q_trim_start) {
         foreach my $i ($seq->q_trim_start .. $seq->q_trim_end) {
            substr($bases,$i,1) = uc(substr($bases,$i,1));
         }
      }
      # insert a restriction site
      substr($bases,$seq->v_trim_end) = '<'.substr($bases,$seq->v_trim_end)
                                                       if ($seq->v_trim_end);
      # insert a vector junction site
      substr($bases,$seq->v_trim_start) = '>'.substr($bases,$seq->v_trim_start)
                                                       if ($seq->v_trim_start);

      my $rowsNeeded = int(length($bases)/50)+1;

      # toss in a <cr> every now and then
      $bases =~ s/(.{50})/$1\n/g;
      print $cgi->center($cgi->start_form(-method=>'post',-action=>'seqTrimmer.pl'),"\n",
                  $cgi->textarea(-name=>"seq",-cols=>54,-rows=>$rowsNeeded, -style=>'font-family: fixed-width, monospace',
                                 -wrap=>'virtual',-value=>$bases),$cgi->br,
                  $cgi->hidden(-name=>'id',-value=>$seq->lane_id),
                  $cgi->submit(-name=>'Submit'),
                  $cgi->end_form(),"\n"),"\n";
      #print $bases;

   }

}

sub processTrimmedSeq
{
   my $cgi = shift;


   # be absolutely sure the id and seq matchup.

   my $id = $cgi->param('id');
   my $seq = $cgi->param('seq');
   $seq =~ s/\s+//sg;

   my $v_trim_start;
   my $v_trim_end;
   my $q_trim_start;
   my $q_trim_end;
   my $workSeq;

   # look for the first > delimiter.
   
   my $displaySeq = $seq;
   $displaySeq =~ s/(.{50})/$1<br>\n/;
   #print "DEBUG:input seq is:<br>\n$displaySeq<br>";

   if (($workSeq = $seq) =~ s/>.*$// ) {
     #print "DEBUG: pre-vector seq is $workSeq<br>";
     $workSeq =~ s/[^A-Z]//ig;
     
     $v_trim_start = length($workSeq);
     #print $cgi->h3("DBG: Vector trimming start found at $v_trim_start."),$cgi->br;
   } else {
     #print $cgi->h3("DBG: No vector trimming start found."),$cgi->br;
   }

   # look for the first < delimiter.
   if (($workSeq = $seq) =~ s/<.*// ) {
     $workSeq =~ s/[^A-Z]//ig;
     $v_trim_end = length($workSeq);
     #print $cgi->h3("Vector trimming end found at $v_trim_end."),$cgi->br;
   } else {
     #print $cgi->h3("No vector trimming end found."),$cgi->br;
   }

   # look for the first ! delimiter.
   if (($workSeq = $seq) =~ s/!.*// ) {
     $workSeq =~ s/[^A-Z]//ig;
     $q_trim_start = length($workSeq);
     #print $cgi->h3("Quality trimming start found at $q_trim_start"),$cgi->br;
   } else {
     #print $cgi->h3("No quality trimming start found."),$cgi->br;
   }
   # look for the first . delimiter.
   if (($workSeq = $seq) =~ s/\..*// ) {
     $workSeq =~ s/[^ACGTNacgtn]//g;
     $q_trim_end = length($workSeq);
     #print $cgi->h3("Quality trimming end found at $q_trim_end."),$cgi->br;
   } else {
     #print $cgi->h3("No quality trimming end found."),$cgi->br;
   }

   ($workSeq = $seq) =~ s/[^ACGTNacgtn]//g;

   my $session = new Session({-log_level=>0});
   my $phred = new Phred_Seq($session,{-lane_id=>$id})->select_if_exists;

   unless ($phred->id ) {
      print $cgi->h3("There is no phred'ed sequence with lane id $id.");
      return;
   }
   my $oldSeq = $phred->seq;
   $oldSeq =~ tr/acgtn/ACGTN/;
   $workSeq =~ tr/acgtn/ACGTN/;

   my $update = 0;

   unless ($oldSeq eq $workSeq) {
      print $cgi->h3("Processing sequence update data...");
      # we need to see how new new and old compares
      my $sim = GH::Sim4::sim4($oldSeq,$workSeq,{A=>1});

      # we need to have a pretty decent hit
      if( !$sim ) {
        print $cgi->em("Cannot compare old sequence to edited sequence. Returning...");
        return;
      }

      if ($sim->{exon_count} != 1 ||
          $sim->{exons}->[0]->{from1} != 1 ||
          $sim->{exons}->[0]->{from2} != 1 ||
          $sim->{exons}->[0]->{to1} != length($oldSeq) ||
          $sim->{exons}->[0]->{to2} != length($workSeq) ) {
        print $cgi->em("Old sequence and edited sequence are too disimilar. Returning...");
        return;
      }

      # we need to 1) replace old with work, and 2) adjust the quality string
      my ($q_match,$a_match,$s_match) = split(/\n/,$sim->{exon_alignment_strings}->[0]);

      print $cgi->pre("DBG: comparison string:\n",$q_match,"\n",$a_match,"\n",$s_match,"\n");

      my $qual = $session->Phred_Qual({-phred_seq_id=>$phred->id});
      unless ($qual->db_exists) {
        print $cgi->em("There is no quality record associated with this phred seq.");
      } else {
        $qual->select;
        my @q = split(/\s+/,$qual->qual);
        my @new_q;
        foreach my $i (1..length($q_match)) {
          if (substr($q_match,$i-1,1) eq ' ') {
            # is this an insertion?
            push @new_q, '99';
            print $cgi->pre("DBG: new sequence has insertion at postion $i\n");
          } elsif (substr($s_match,$i-1,1) eq ' ') {
            # or a deletion?
            print $cgi->pre("DBG: new sequence has deletion at postion $i\n");
            shift @q;
          } elsif (substr($a_match,$i-1,1) ne '|') {
            # or a base change?
            shift @q,
            push @new_q, '99';
            print $cgi->pre("DBG: new sequence has replacement at postion $i\n");
          } else {
            # or a match
            push @new_q, (shift @q);
          }
        }

        print $cgi->pre("DBG: quality length and new sequence length agree.\n") if scalar(@new_q) == length($workSeq);
        unless(scalar(@new_q) == length($workSeq) ) {
          print $cgi->em("There is some trouble generating alignment. Cannot process these.");
          return;
        }

        print $cgi->pre("DBG: old quality: ",$qual->qual,"\n");
        print $cgi->pre("DBG: new quality: ",join(' ',@new_q),"\n");
        # process this...
        $qual->qual(join(' ',@new_q));
        $qual->update;
        $phred->seq($workSeq);
        $phred->last_update('now');
        $phred->update;
        print $cgi->b("Sequence updated.");
      }
   }

   print $cgi->h3("Processing trimming data...");

   if ($v_trim_start ne '' && $phred->v_trim_start != $v_trim_start) {
      print $cgi->b("Updating vector trimming from ".
                 $phred->v_trim_start." to $v_trim_start."),$cgi->br;
      $phred->v_trim_start($v_trim_start);
      $update = 1;
   } elsif ($v_trim_start eq '') {
      $phred->v_trim_start(undef);
      $update = 1;
   }
   
   if ($v_trim_end ne '' && $phred->v_trim_end != $v_trim_end) {
      print $cgi->b("Updating restriction site trimming from "
                 .$phred->v_trim_end." to $v_trim_end."),$cgi->br;
      $phred->v_trim_end($v_trim_end);
      $update = 1;
   } elsif ($v_trim_end eq '') {
      $phred->v_trim_end(undef);
      $update = 1;
   }
   
   if ($q_trim_start ne '' && $phred->q_trim_start != $q_trim_start) {
      print $cgi->b("Updating quality trimming start from "
                 .$phred->q_trim_start." to $q_trim_start."),$cgi->br;
      $phred->q_trim_start($q_trim_start);
      $update = 1;
   }
   
   if ($q_trim_end ne '' && $phred->q_trim_end != $q_trim_end) {
      print $cgi->b("Updating quality trimming end from "
                 .$phred->q_trim_end." to $q_trim_end."),$cgi->br;
      $phred->q_trim_end($q_trim_end);
      $update = 1;
   }

   $phred->last_update('now');
   $phred->update if $update;

   if ($update) {
     print $cgi->b("Sequence records updated."),$cgi->br,"\n";
   } else {
     print $cgi->b("No trimming updates given."),$cgi->br,"\n";
   }
   
   return;
}
