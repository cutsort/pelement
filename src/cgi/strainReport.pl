#!/usr/local/bin/perl -I../modules

=head1 NAME

  strainReport.pl Web report of the strain information.

=cut

use Pelement;
use Session;
use Strain;
use Seq;
use SeqSet;
use Seq_AlignmentSet;
use Seq_Alignment;
use Blast_Report;
use GenBankScaffold;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;
my $strain = $cgi->param('strain');

print $cgi->header;
print $cgi->init_page;
print $cgi->banner;


if ($strain) {
   reportStrain($cgi,$strain);
} else {
   selectStrain($cgi);
}

print $cgi->footer([
                   {link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                    ]);
print $cgi->close_page;

exit(0);


sub selectStrain
{

  my $cgi = shift;
  
  print
    $cgi->center(
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

  # try to make sense of the strain name. It may have an end identifier.
  my $s = new Strain($session,{-strain_name=>$strain});

  if (!$s->db_exists  && $strain =~ /-[35]$/ ) {
     $strain =~ s/-[35]//;
     $s->strain_name($strain);
  }

  if ( !$s->db_exists ) {
     print $cgi->center($cgi->h2("No flanking sequence for strain $strain.")),"\n";
     return;
  }

  my $seqSet = new SeqSet($session,{-strain_name=>$s->strain_name})->select;

  my %db_name = ( "release3_genomic" => "Release 3 Genomic",
                  "na_te.dros"       => "Transposable Elements",
                );
  my %subject_name = ( arm_2L => "2L",
                       arm_2R => "2R",
                       arm_3L => "3L",
                       arm_3R => "3R",
                       arm_X  => "X",
                       arm_4  => "4");

  my $seq_names = '(';
  my @tableRows = ();

  my %insertLookup = ();

  foreach my $seq ($seqSet->as_list) {
     my $a = $seq->seq_name;
     my $b = $seq->insertion_pos;
     my $c = $seq->sequence;
     $insertLookup{$a} = $b;
     my $len = length($c);
     $c =~ s/(.{50})/$1<br>/g;
     $c = "<tt>".$c."</tt>";
     push @tableRows, $cgi->td({-align=>'center'},[$a,$len,$b]).$cgi->td({-align=>'left'},[$c]);
     $seq_names .= "'$a',";
  }
  $seq_names =~ s/,$/)/;


  print $cgi->center($cgi->h3("Flanking sequence for strain $strain"),$cgi->br),"\n";

  print $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Sequence<br>Name","Length","Insert<br>Position","Sequence"] ),
                           @tableRows,
                           #(map { $cgi->td({-align=>"left"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";

  print $cgi->br,"\n";


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
            $a = new Seq_Alignment($session);
            $a->from_Blast_Report($b);

            # do nothing if this is already there (may have been a reload)
            unless ($a->db_exists) {
               $a->status('curated');
               $a->insert;
            }
         }
      }
   } elsif ($cgi->param('action') eq 'ignore' || $cgi->param('action') eq 'accept') {
      if (!$cgi->param('id') ) {
         print $cgi->center($cgi->em("Internal trouble with CGI parameter id.")),"\n";
      } else {
         my $seq_a = new Seq_Alignment($session,{-id=>$cgi->param('id')})->select_if_exists;
         # be paranoid. Make sure this id corresponds to this strain
         my $paranoid = 0;
         map {$paranoid = 1 if $seq_a->seq_name eq $_->seq_name} @{$seqSet->as_list};
         if (!$seq_a->id || $paranoid) {
            print $cgi->center($cgi->em("Internal trouble with CGI parameter id.")),"\n";
         } else {
            if ($cgi->param('action') eq 'accept') {
               $seq_a->status('curated');
               $seq_a->update;
            } elsif ( $cgi->param('action') eq 'ignore') {
               $seq_a->status('deselected');
               $seq_a->update;
            }
         }
      }
   }
  print $cgi->center($cgi->h3("Sequence alignments"),$cgi->br),"\n";

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

        my $link;
        if ($seq_a->status eq "unique" || $seq_a->status eq "curated") {
           $link = "<a href=\"strainReport.pl?id=".$seq_a->id.
                            "&action=ignore&strain=$strain\">Disregard</a>";
        } elsif ($seq_a->status eq "multiple" || $seq_a->status eq "deselected") {
           $link = "<a href=\"strainReport.pl?id=".$seq_a->id.
                            "&action=accept&strain=$strain\">Accept</a>";
        } else {
           $link = "non-standard";
        }

        push @tableRows, [$seq_a->seq_name,$p_range,$scaffold_name,$strand,
                          $seq_a->s_start."-".$seq_a->s_end,$seq_a->s_insert,
                          $seq_a->status,$link];
     }
  }
  print $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Sequence<br>Name","Flanking<br>Range","Subject","Strand",
                           "Subject<br>Range","Insertion<br>Position","Status",
                           "Alignment<br>Curation"] ),
                           (map { $cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";

  print $cgi->center($cgi->br,$cgi->h3("Blast Hits for Flanking Sequences")),"\n";

  foreach $db (sort keys %db_name) {
     my @values = ();
     my $sql = qq(select seq_name,query_begin,query_end,name,subject_begin,subject_end,score,match,
                  length,percent,id from blast_report where
                  seq_name in ).$seq_names.qq(and db=').$db.
                  qq(' order by seq_name desc,score desc);

     $session->db->select($sql,\@values);
     my @tableRows = ();

     if (@values) {

        print $cgi->h3("Hits to $db_name{$db}"),$cgi->br,"\n";

        # the mini_table is a hash indexed by seq_name with elements references to
        # a list of blast hit list references
        my %mini_table;

        while (@values) {
           my ($sn,$qs,$qe,$n,$c,$d,$e,$f,$g,$h,$i) = splice(@values,0,11);

           # let's see if the flank hit includes the insertion
           ($qs,$qe) = sort { $a <=> $b } ($qs,$qe);
           my $flank_range = $qs."-".$qe;
           if ($insertLookup{$sn} && $qs <= $insertLookup{$sn} && $insertLookup{$sn} <= $qe) {
              $flank_range = "<b>".$flank_range."</b>";
           }

           $mini_table{$sn} = [] unless exists($mini_table{$sn});

           my $b2 = exists($subject_name{$n})?$subject_name{$n}:$n;
           $detailLink = "<a href=\"blastReport.pl?id=" . $i . "\" target=\"_blast\">" .
                          $f . "/" . $g. " (" . $h . "%)</a>";
           if ($alignedHSP{$i}) {
              $alignLink = "Alignment #$alignedHSP{$i}";
           } else {
              $alignLink = "<a href=\"strainReport.pl?id=".$i.
                                           "&action=align&strain=$strain\">Align</a>";
           }
           if ($db eq "release3_genomic") {
              my $gb = new GenBankScaffold($session)->mapped_from_arm($n,$c);
              my $gb_info;
              if ($gb && $gb->accession) {
                 my $gb_start = $c - $gb->start + 1;
                 my $gb_stop = $d - $gb->start + 1;
                 $gb_info = $gb->accession.' '.$gb_start.'-'.$gb_stop;
              } else {
                 $gb_info = '&nbsp';
              }
              push @{$mini_table{$sn}}, [$flank_range,$b2,$c."-".$d,$gb_info,$detailLink,$alignLink];
           } else {
              push @{$mini_table{$sn}}, [$flank_range,$b2,$c."-".$d,$detailLink,$alignLink];
           }
        }

   
        print $cgi->center($cgi->table({-bordercolor=>$HTML_TABLE_BORDERCOLOR,
                                                      -border=>4,-width=>"95%"},
                 $cgi->Tr( [
                    $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                             ["Sequence<br>Name","Blast Hits"] ),
                              (map { $cgi->td({-align=>"center"}, $_ ) }
                                  (map { [$_,format_minitable($cgi,$db,$mini_table{$_})] }
                                               sort { $b cmp $a } keys %mini_table)) ])));
                        
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
 
   $cgi->table({-border=>2,-width=>"100%"},$cgi->Tr( [ 
         $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR2},
                     ["Flank Range","Subject","Range",
                   (($db eq "release3_genomic")?"GenBank":()),
                 "Alignment","Generate<br>Alignment"] ),
                 (map { $cgi->td({-align=>"center"}, $_ ) } @$listRef)
                             ] ))."\n";
}
