#!/usr/local/bin/perl -I../modules

=head1 NAME

  assemblyReport.pl Web report of the how a sequence was assembled

=cut

use Pelement;
use Session;
use Strain;
use Seq;
use SeqSet;
use Strain;
use Seq_Assembly;
use Seq_AssemblySet;
use Gel;
use Lane;
use Phred_Seq;
use Blast_Report;
use Processing;
use PelementCGI;
use PelementDBI;

use GH::Sim4;

$cgi = new PelementCGI;
my $strain = $cgi->param('strain');
my $seq_name = $cgi->param('seq_name');

print $cgi->header;
print $cgi->init_page({-title=>"$strain Assembly Report"});
print $cgi->banner;


if ($strain) {
   reportStrain($cgi,$strain);
} elsif ($seq_name) {
   reportSeqAssemblyAlignment($cgi,$seq_name);
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

sub reportSeqAssemblyAlignment
{
   my ($cgi,$seq_name) = @_;

   my $session = new Session({-log_level=>0});

   # did we get an id? Let's hope so;
   my $id = $cgi->param('id');

   unless( $id ) {
      print $cgi->center($cgi->h2("No id specified for the alignment to $seq_name.")),"\n";
      return;
   }

   my $sA = new Seq_Assembly($session,{-seq_name=>$seq_name,src_seq_id=>$id});
   unless ($sA->db_exists) {
      print $cgi->center($cgi->h2("No sequence with id specified for the alignment to $seq_name.")),"\n";
      return;
   }
   $sA->select;

   my $cS = new Seq($session,{-seq_name=>$seq_name});
   unless ($cS->db_exists) {
      print $cgi->center($cgi->h2("No sequence in the db with name $seq_name.")),"\n";
      return;
   }
   
   my $conSeq = $cS->select->sequence;
   my $alignSeq;
   # are we displaying things rev-comped?
   my $flipped = 0;
   if ($sA->src_seq_src eq 'phred_seq') {
      my $pS = new Phred_Seq($session,{-id=>$id});
      unless ($pS->db_exists) {
         print $cgi->center($cgi->h2("No sequence in the db with id $id.")),"\n";
         return;
      }
      $alignSeq = $pS->select->trimmed_seq;
      if (Seq::end($seq_name) eq '5') {
         $alignSeq = Seq::rev_comp($alignSeq);
         $flipped = 1;
      }
   }

   my $r = GH::Sim4::sim4($conSeq,$alignSeq,{A=>1});

   unless ($r->{exon_count} == 1) {
      print $cgi->center($cgi->h2("The Sim4 alignment does not result in a single exon hit. Whazzup?")),$cgi->br,"\n";
      print $cgi->center("some details. exon_count = ",$r->{exon_count});
      foreach my $i (0..$r->{exon_count}) {
        my $exon = $r->{exons}[$i];
        print $cgi->center("subject begin,end ",$exon->{from1}," ",$exon->{to1});
        print $cgi->center("query begin,end ",$exon->{from2}," ",$exon->{to2});
        print $cgi->center("alignment string",$r->{exon_alignment_strings}[$i]);
        print $cgi->br;
      }
      return;
   }

   # make a blast report object for this sim4 hit:
   # we've already checked that we have only 1 exon

   my $bR = new Blast_Report($session);
   my $exon = $r->{exons}[0];

   $bR->db('P element Sequence Database');
   $bR->name($seq_name);
   $bR->seq_name('Component of '.$seq_name);

   $bR->strand(1);
   $bR->subject_begin($exon->{from1});
   $bR->subject_end($exon->{to1});
   #if ($flipped) {
   #   $bR->query_begin($exon->{to2});
   #   $bR->query_end($exon->{from2});
   #} else {
      $bR->query_begin($exon->{from2});
      $bR->query_end($exon->{to2});
   #}
   $bR->percent($exon->{match});
   $bR->match($exon->{nmatches});
   $bR->length($exon->{length});
   # this is the M=+5, N=-4 scoring scheme
   $bR->score(9*$exon->{nmatches} - 4*$exon->{length});
   
   $bR->bits(0);
   $bR->query_gaps(0);
   $bR->subject_gaps(0);
   $bR->p_val(0.);

   my @aStr = split(/\n/,$r->{exon_alignment_strings}[0]);
   $bR->subject_align($aStr[0]);
   $bR->match_align($aStr[1]);
   $bR->query_align($aStr[2]);

   $orient = $cgi->param('orient') || 1;
   print $bR->to_html($cgi,$orient);
   $orient = -1*$orient;
   print $cgi->center($cgi->a({-href=>'assemblyReport.pl?seq_name='.$seq_name.'&id='.$id.'&orient='.$orient,
                               -target=>"_blast"},
                               'Reverse Complement Alignment').$cgi->br);

}

sub reportStrain
{
  my ($cgi,$strain) = @_;

  my $session = new Session({-log_level=>0});

  # try to make sense of the strain name. It may have embedded spaces
  $strain =~ s/\s+//g;
  # or a strange terminating periods from cutting-n-pasting
  $strain =~ s/\.$//g;
  my $s = new Strain($session,{-strain_name=>Seq::strain($strain)});

  if ( !$s->db_exists ) {
     print $cgi->center($cgi->h2("No flanking sequence for strain $strain.")),"\n";
     return;
  }

  my $seqSet = new SeqSet($session,{-strain_name=>$s->strain_name})->select;

  my @tableRows = ();

  foreach my $seq ($seqSet->as_list) {
     my $sAS = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;

     my $info;
     
     foreach my $sA ($sAS->as_list) {
        if ($sA->src_seq_src eq 'phred_seq') {

           # trace this back and find the highest level we can 
           my $linkText = "Phred Sequence ".$sA->src_seq_id;
           my $phredFrom = new Phred_Seq($session,{-id=>$sA->src_seq_id})->select();
           if ($phredFrom && $phredFrom->lane_id) {
              my $laneFrom = new Lane($session,{-id=>$phredFrom->lane_id})->select();
              if ($laneFrom && $laneFrom->file) {
                 $linkText = "Sequence from ".$laneFrom->file;
              }
              if ($laneFrom && $laneFrom->gel_id) {
                 my $gelFrom = new Gel($session,{-id=>$laneFrom->gel_id})->select;
                 if ($gelFrom && $gelFrom->id) {
                    $linkText = "Sequence from gel ".$gelFrom->name.":".$laneFrom->well;
                 }
                 if ($gelFrom && $gelFrom->ipcr_name && $gelFrom->ipcr_name ne 'untracked' ) {
                    $linkText = "Sequence from batch ".Processing::batch_id($gelFrom->ipcr_name).":".$laneFrom->well;
                 }
              }
           }
           $info .= $cgi->a({-href=>'seqReport.pl?db=phred_seq&id='.$sA->src_seq_id,
                           -target=>'_seq'},$linkText).' assembled '.$sA->assembly_date.
                    $cgi->a({-href=>'assemblyReport.pl?seq_name='.$sA->seq_name.'&id='.$sA->src_seq_id,
                             -target=>"_blast"},
                            ' Show Alignment').$cgi->br;

        } elsif ($sA->src_seq_src eq 'seq') {
           my $b = new Seq($session,{-id=>$sA->src_seq_id})->select_if_exists;
           if ($b->seq_name) {
              $info .= $cgi->em('Assembled from '.$b->seq_name).' on '.$sA->assembly_date.$cgi->br;
           } else {
              $info .= $cgi->em('Assembled from a sequence which has disappered!').$cgi->br;
           }
        } else {
           $info .= $cgi->em('Internal db inconsistency!');
        }
     }
     $info = $cgi->em('This sequence assembly not tracked in the database.') unless $info;
        
     push @tableRows, $cgi->td({-align=>'center'},[$seq->seq_name]).$cgi->td({-align=>'left'},[$info]);
  }
  $seq_names =~ s/,$/)/;


  print $cgi->center($cgi->h3("Sequence Data Source Tracking For Strain $strain"),$cgi->br),"\n";

  print $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Sequence<br>Name","Data Source"] ),
                           @tableRows,
                       ] )
                     )),"\n";

  print $cgi->br,"\n";


  $session->exit;
}
