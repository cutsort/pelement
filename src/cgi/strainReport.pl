#!/usr/local/bin/perl -I../modules

=head1 NAME

   strainReport.pl Web report of the strain information.

=cut

use Pelement;
use Session;
use Strain;
use Seq;
use SeqSet;
use SampleSet;
use Strain_Alias;
use Batch;
use Seq_AlignmentSet;
use Seq_Alignment;
use Blast_Report;
use Blast_ReportSet;
use Blast_Run;
use Blast_RunSet;
use GenBankScaffold;
use Submitted_Seq;
use PelementCGI;
use PelementDBI;

use strict;

my $cgi = new PelementCGI;
my $strain = $cgi->param('strain');

print $cgi->header;
print $cgi->init_page({-title=>"$strain Strain Report"});
print $cgi->banner;

$cgi->param('max_hits',10) unless $cgi->param('max_hits');

if ($strain) {
   reportStrain($cgi,$strain);
} else {
   selectStrain($cgi);
}

print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                   {link=>"setReport.pl",name=>"Set Report"},
                    ]);
print $cgi->close_page;

exit(0);


sub selectStrain
{

   my $cgi = shift;
  
   print $cgi->center(
       $cgi->h3("Enter the Strain Name:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"strainReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["Strain",$cgi->textfield(-name=>"strain")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form,"\n",
    ),"\n";
}

sub reportStrain
{
   my ($cgi,$strain) = @_;

   my $session = new Session({-log_level=>0});

   # try to make sense of the strain name. It may have an end identifier or other characters
   $strain =~ s/\s+//g;
   # and get rid of strange periods from cutting-n-pasting
   $strain =~ s/\.$//g;

   my $s = new Strain($session,{-strain_name=>$strain});
   # maybe this does not exists. trim off any end id's
   if (! $s->db_exists ) {
     $strain = Seq::strain($strain);
     $s = new Strain($session,{-strain_name=>$strain});
   }

   # try again, stripping off insertion id.
   if ( !$s->db_exists && $strain =~ /(.*)[a-z]$/) {
     $strain = $1;
     $s = new Strain($session,{-strain_name=>$strain});
   }

   if ( !$s->db_exists ) {
      # if this doesn't exists, check to see if it is an alias
      my $al = new Strain_Alias($session,{-alias=>Seq::strain($strain)})->select_if_exists;
      if ($al && $al->strain_name ) {
         $s = new Strain($session,{-strain_name=>$al->strain_name});
         print $cgi->center($cgi->em(Seq::strain($strain)." is an alias for ".$s->strain_name.".")); 	
         $cgi->param('strain',$al->strain_name);
         if (!$s->db_exists ) {
            print $cgi->center($cgi->h2("No record of strain ".Seq::strain($strain).".")),"\n";
            return;
         }
      } else {
         print $cgi->center($cgi->h2("No record of strain ".Seq::strain($strain)." or aliases.")),"\n";
      }
   }

   # what batch was this strain in?
   my $sampleSet = new SampleSet($session,{-strain_name=>$cgi->param('strain')})->select();

   my @tableRows = ();
   foreach my $s ($sampleSet->as_list) {

      my $ba = new Batch($session,{-id=>$s->batch_id});
      next unless $ba->db_exists;
      $ba->select;
      push @tableRows, [
                $s->strain_name,uc($s->well),
                $cgi->a({-href=>"batchReport.pl?batch=".$ba->id},"Batch ".$ba->id),
                $ba->batch_date || $cgi->nbsp ];
   }

   # sort by date, then batch id, then well
   @tableRows = sort { PCommon::date_cmp($a->[3],$b->[3]) ||
                       $a->[2] cmp $b->[2] ||
                       $a->[1] cmp $b->[1] } @tableRows;

   if (@tableRows) {

      print $cgi->center($cgi->h3("Production Records"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,
                                -width=>"80%",
                                -bordercolor=>$HTML_TABLE_BORDERCOLOR},
         $cgi->Tr( [
            $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'10%'},
                   ["Strain".$cgi->br."Name"]).
            $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'5%'},
                   ["Well"]).
            $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR,-width=>'15%'},
                   ["Batch","Date"]),
                   (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                    ] )
                  )),"\n",$cgi->br,$cgi->hr({width=>'70%'}),"\n";

   } else {
       # do we need to print this?
       #print $cgi->h3("No batches were found for ".$cgi->param('strain')),"\n";
   }
  
   my $seqSet = new SeqSet($session,{-strain_name=>$s->strain_name})->select;

   my %db_name = ( "release3_genomic" => "Release 3 Genomic",
                  "vector"           => "Vector Contaminates",
                  "na_te.dros"       => "Transposable Elements",
                );
   my %subject_name = ( arm_2L => "2L",
                       arm_2R => "2R",
                       arm_3L => "3L",
                       arm_3R => "3R",
                       arm_X  => "X",
                       arm_4  => "4");

   my @tableRows = ();

   # all of the seq names associated with this strain
   my @seq_names = ();

   my %insertLookup = ();

   foreach my $seq (sort { $a->seq_name cmp $b->seq_name } $seqSet->as_list) {
     my $s = $seq->seq_name;
     my $i = $seq->insertion_pos;
     my $r = $seq->sequence;
     my $q = $seq->qualifier;
     if ($q =~ /^\d+$/ ) {
        $q = 'Transitory';
     } elsif ($q =~ /^r\d+$/ ) {
        $q = 'Unconfirmed Recheck';
     } elsif ($q =~ /^[a-z]+$/ ) {
        $q = 'Curated';
     } else {
        $q = 'Current';
     }
     $insertLookup{$s} = $i;
     my $len = length($r);
     $r =~ s/(.{50})/$1<br>/g;
     $r = "<tt>".$r."</tt>";

     my $acc = new Submitted_Seq($session,{-seq_name=>$seq->seq_name})->select_if_exists;
     my $accNo = $acc->gb_acc || $cgi->nbsp;
     
     push @tableRows, $cgi->td({-align=>'center'},
                       [$cgi->a({-href=>'assemblyReport.pl?strain='.$s},$s),$len,$i]).
                      $cgi->td({-align=>'left'},[$r]).
                      $cgi->td({-align=>'center'},[$cgi->a({-href=>'seqStatusReport.pl?seq='.$s},$q),$accNo]);
     push @seq_names, $seq->seq_name;
   }


   if (@tableRows) {
      print $cgi->center($cgi->h3("Flanking Sequencs"),$cgi->br),"\n";

      print $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
              $cgi->Tr( [
                 $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                         ["Sequence<br>Name","Length","Insert<br>Position","Sequence","Status","Accession"] ),
                              @tableRows,
                          ] )
                        )),"\n";

      print $cgi->br,"\n";
   } else {
      # no flanking sequence (yet), but we won't return until after we put up
      # the edit genotype/phenotype link
      print $cgi->center($cgi->h3("No flanking sequence in the database for $strain"),$cgi->br),"\n";
   }


   print $cgi->center($cgi->a({-href=>"phenoReport.pl?strain=".$s->strain_name},
                             "Edit Genotype/Phenotype information on ".$s->strain_name)),
                      $cgi->br,$cgi->hr({width=>'70%'}),"\n";

   return unless @tableRows;

   # before generating a report, we need to see if there is a requested action
   # possibilities are
   #       (1) align: generate an alignment based on a HSP. This requires a hsp_id parameter
   #       (2) ignore: toss an automatic (or manual) alignment onto the 'do not use' list
   #       (3) accept: promote one of the multiple alignments into the 'curated' category.
   #           the last two require an alignment id parameter.

   if ($cgi->param('action') eq 'align') {
      if (!$cgi->param('id')  || $cgi->param('id') !~ /^\d+$/ ) {
         print $cgi->center($cgi->em("Internal trouble with CGI parameter id.")),"\n";
      } else {
         # the id we get is based on the blast_report id
         my $b = new Blast_Report($session,{-id=>$cgi->param('id')})->select_if_exists;
         if (!$b->seq_name ) {
            print $cgi->center($cgi->em("Internal trouble with CGI parameter id.")),"\n";
         } else {
            my $sa = new Seq_Alignment($session);
            $sa->from_Blast_Report($b);

            # do nothing if this is already there (may have been a reload)
            unless ($sa->db_exists) {
               $sa->status('curated');
               $sa->insert;
            }
         }
      }
   } elsif ($cgi->param('Curate') eq 'Curate') {
      if (!$cgi->param('id') ) {
         print $cgi->center($cgi->em("Internal trouble with CGI parameter id.")),"\n";
      } else {
         my $seq_a = new Seq_Alignment($session,{-id=>$cgi->param('id')})->select_if_exists;
         # be paranoid. Make sure this id corresponds to this strain
         my $paranoid = 0;
         map {$paranoid = 1 if $seq_a->seq_name eq $_->seq_name} $seqSet->as_list;
         if (!$seq_a->id || !$paranoid) {
            print $cgi->center($cgi->em("Internal trouble with CGI parameter id.")),"\n";
         } else {
            if ($cgi->param('status') eq 'curated') {
               $seq_a->status('curated');
               $seq_a->update;
            } elsif ( $cgi->param('status') eq 'deselected') {
               $seq_a->status('deselected');
               $seq_a->update;
            } elsif ( $cgi->param('status') eq 'unwanted') {
               $seq_a->status('unwanted');
               $seq_a->update;
            }
         }
      }
   }

   # I gotta get these table joins to work.
   my @tableRows = ();
   my %alignedHSP = ();
   my $ctr = 1;

   foreach my $seq ($seqSet->as_list) {
     my $seqAlignmentSet = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;
     foreach my $seq_a ($seqAlignmentSet->as_list ) {


        $alignedHSP{$seq_a->hsp_id} = $ctr++;
        # s_end is always > s_start. p_start > p_end is a sign of - string
        my $strand = ($seq_a->p_end>$seq_a->p_start)?"+":"-";

        # always show the hit on the pelement coordinates as (small) - (big)
        my $p_range = ($strand eq '+')? $seq_a->p_start .'-'. $seq_a->p_end:
                                        $seq_a->p_end .'-'. $seq_a->p_start;

        my $scaffold_name = exists($subject_name{$seq_a->scaffold})?
                                   $subject_name{$seq_a->scaffold}:
                                   $seq_a->scaffold;

        # we need to delete the id parameter to get the hidden id to work.
        $cgi->delete('id');
        $cgi->delete('status');
        my $link = $cgi->start_form( -method => 'get',
                                     -action => 'strainReport.pl').
                      $cgi->hidden(-name=>'strain',-value=>$strain).
                      $cgi->hidden(-name=>'id',-value=>$seq_a->id).
                      $cgi->popup_menu(-name => 'status',
                                    -default => $seq_a->status eq 'multiple'?'curated':$seq_a->status,
                                     -values => ['curated','deselected','unwanted']).
                      $cgi->submit(-name => 'Curate').
                   $cgi->end_form;

        push @tableRows, [$seq_a->seq_name,$p_range,$scaffold_name,$strand,
                          $seq_a->s_start."-".$seq_a->s_end,$seq_a->s_insert,
                          $seq_a->status,$link];
     }
   }
   if (@tableRows) {
      @tableRows = sort { $a->[2] cmp $b->[2] ||
                          $a->[5] <=> $b->[5] ||
                          $a->[0] cmp $b->[0] } @tableRows;

      print $cgi->center($cgi->h3("Sequence Alignments"),$cgi->br),"\n",
            $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
              $cgi->Tr( [
                 $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                         ["Sequence<br>Name","Flanking<br>Range","Subject","Strand",
                              "Subject<br>Range","Insertion<br>Position","Status",
                              "Alignment<br>Curation"] ),
                              (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                          ] )
                        )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
   } else {
      print $cgi->center($cgi->h3("No Sequence Alignments"),$cgi->br),$cgi->hr({-width=>'70%'}),"\n",
   }


   print $cgi->center($cgi->br,$cgi->h3("Blast Hits")),"\n";

   foreach my $db (sort keys %db_name) {

     # when did we do this?
     my @blast_runs = ();
     my @blast_hits = ();

     # the mini_table is a hash indexed by seq_name with elements references to
     # a list of blast hit list references
     my %mini_table;

     # we'll use the absence of a hit to indicated that we need to add a link
     map {$mini_table{$_} = [] } @seq_names if $db eq 'release3_genomic';

     map { push @blast_runs,
            new Blast_RunSet($session,{-seq_name=>$_,-db=>$db})->select->as_list } @seq_names;
     map { push @blast_hits,
            new Blast_ReportSet($session,{-seq_name=>$_,-db=>$db})->select->as_list } @seq_names;

     @blast_runs = sort { PCommon::date_cmp($a->date,$b->date) } @blast_runs;

     foreach my $b (@blast_runs) {
        print $cgi->em(($b->program || 'blastn')." of ".$b->seq_name." to ".$b->db." performed ".$b->date."."),$cgi->br;
     }

     #my $sql = qq(select seq_name,query_begin,query_end,name,subject_begin,subject_end,score,match,
     #             length,percent,id from blast_report where
     #             seq_name in ).$seq_names.qq(and db=').$db.
     #             qq(' order by seq_name desc,score desc);

     my @tableRows = ();

     if (@blast_hits) {

        print $cgi->h3("Hits to $db_name{$db}"),
              $cgi->a({-href=>"strainReport.pl?strain=$strain&max_hits=all"},
                       'Show all blast hits'),$cgi->br,"\n"
                       if $cgi->param('max_hits') =~ /^\d+$/ && scalar(@blast_hits) > $cgi->param('max_hits');


        foreach my $bH (@blast_hits) {

           # let's see if the flank hit includes the insertion
           my ($qs,$qe) = sort { $a <=> $b } ($bH->query_begin,$bH->query_end);
           my $flank_range = $qs."-".$qe;
           if ($insertLookup{$bH->seq_name} && $qs <= $insertLookup{$bH->seq_name} && $insertLookup{$bH->seq_name} <= $qe) {
              $flank_range = "<b>".$flank_range."</b>";
           }

           my $b2 = exists($subject_name{$bH->name})?$subject_name{$bH->name}:$bH->name;
           my $detailLink = $cgi->a({-href=>"blastReport.pl?id=".$bH->id,-target=>"_blast"},
                                              $bH->match."/".$bH->length."(".$bH->percent."%)");
           my $alignLink;
           if ($alignedHSP{$bH->id}) {
              $alignLink = "Alignment #$alignedHSP{$bH->id}";
              # <hack>
              # we really want the blast hits that are used in alignments to show up near the
              # top of the blast report. These will be sorted by score, so what we're gonna
              # do is elevate the score for those hits that are used in alignments.
              $bH->score($bH->score() + 50000);
              # </hack>
           } else {
              $alignLink = $cgi->a({-href=>"strainReport.pl?id=".$bH->id.
                                    "&action=align&strain=$strain"},"Align");
           }

           if ($db eq "release3_genomic") {
              my $gb = new GenBankScaffold($session)->mapped_from_arm($bH->name,$bH->subject_begin);
              my $gb_info;
              if ($gb && $gb->accession) {
                 my $gb_start = $bH->subject_begin - $gb->start + 1;
                 my $gb_stop = $bH->subject_end - $gb->start + 1;
                 $gb_info = $gb->accession.' '.$gb_start.'-'.$gb_stop;
              } else {
                 $gb_info = '&nbsp';
              }
              push @{$mini_table{$bH->seq_name}},
                   [$bH->score,$flank_range,$b2,$bH->subject_begin."-".$bH->subject_end,$gb_info,$detailLink,$alignLink]
                     ;# unless ($cgi->param('max_hits') =~ /^\d+$/ &&
                     #         scalar(@{$mini_table{$bH->seq_name}}) > $cgi->param('max_hits'));
           } else {
              $mini_table{$bH->seq_name} = [] unless exists($mini_table{$bH->seq_name});
              push @{$mini_table{$bH->seq_name}},
                   [$bH->score,$flank_range,$b2,$bH->subject_begin."-".$bH->subject_end,$detailLink,$alignLink]
                     ;# unless ($cgi->param('max_hits') =~ /^\d+$/ &&
                     #         scalar(@{$mini_table{$bH->seq_name}}) > $cgi->param('max_hits'));
           }
        }

   
        print $cgi->center($cgi->table({-bordercolor=>$HTML_TABLE_BORDERCOLOR,
                                                      -border=>4,-width=>"95%"},
                 $cgi->Tr( [
                    $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                             ["Sequence<br>Name","Blast Hits"] ),
                              (map { $cgi->td({-align=>"center"}, $_ ) }
                                  (map { [$_.linkit($db,$_),format_minitable($cgi,$db,$mini_table{$_})] }
                                               sort { $b cmp $a } keys %mini_table)) ])));
                        
                 sub linkit { my ($db,$seq) = @_;
                    return $cgi->br.$cgi->a({-href=>"hitMaker.pl?seq=".$seq,-target=>'_hit'},'Manual Alignment')
                           if ($db eq 'release3_genomic');
                 }
     } else {
        print $cgi->center($cgi->em("No recorded blast hits to $db_name{$db}.")),$cgi->br,"\n";
     }
     print $cgi->br,"\n";
   }

   $session->exit;
}

=head1 format_minitable

   A convenience routine to formatting the embedded blast hit table. Useful only
   to make the nested table print slightly less unreadable.

=cut

sub format_minitable
{
   my ($cgi,$db,$listRef) = @_;

   return 'No hits found' if $db eq 'release4_genomic' && !scalar(@$listRef);
   return unless scalar @$listRef;

   # sort by score. We will not be showing the score in the output, though.
   @$listRef = sort {$b->[0] <=> $a->[0]} @$listRef;
   # and now drop the score.
   map { shift @$_ } @$listRef;

   if ($cgi->param('start_hit') =~ /^\d+$/ && $cgi->param('start_hit') > 0 ) {
      # undocumented parameter
      @$listRef = splice(@$listRef,$cgi->param('start_hit')-1);
   }
   if ($cgi->param('max_hits') =~ /^\d+$/ && $cgi->param('max_hits') > 0 ) {
      # undocumented parameter
      @$listRef = splice(@$listRef,0,$cgi->param('max_hits')-1);
   }
 
   return 
   $cgi->table({-border=>2,-width=>"100%"},$cgi->Tr( [ 
         $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR2},
                     ["Flank Range","Subject","Range",
                   (($db eq "release3_genomic")?"GenBank":()),
                 "Alignment","Generate<br>Alignment"] ),
                 (map { $cgi->td({-align=>"center"}, $_ ) } @$listRef)
                             ] ))."\n";
}
