#!/usr/local/bin/perl -I../modules

=head1 NAME

  assemblyReport.pl Web report of the how a sequence was assembled

=cut

use strict;

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
use LaneSet;
use Phred_Seq;
use Blast_Report;
use Processing;
use PelementCGI;
use PelementDBI;


use GH::Sim4;

my $cgi = new PelementCGI;
my $strain = $cgi->param('strain');
my $seq_name = $cgi->param('seq_name');

print $cgi->header;
print $cgi->init_page({-title=>"$strain Assembly Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner;


if ($strain) {
   reportStrain($cgi,$strain);
   print $cgi->center($cgi->a({-href=>'strainReport.pl?strain='.Seq::strain($strain)},
                               'Return to Report for '.Seq::strain($strain)).$cgi->br);
} elsif ($seq_name && $cgi->param('action') ) {
   rebuildSeqAssembly($cgi,$seq_name);
   print $cgi->center($cgi->a({-href=>'strainReport.pl?strain='.Seq::strain($seq_name)},
                               'Return to Report for '.Seq::strain($seq_name)).$cgi->br);
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
                $cgi->td({-colspan=>2,-align=>"center"},
                                 [$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                 [$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form,"\n",
    ),"\n";
}

   
sub rebuildSeqAssembly
{
   my ($cgi,$seq_name) = @_;
   my $session = new Session({-log_level=>0});

   my $action = $cgi->param("action");

   # make sure seq_name is legit. A bogus value could spoof us.
   if ($seq_name) {

     if ($action eq 'import') {

       # a potential security hole: we'll be passing this as an argument
       # to a script so we need to make sure the seq_name is legitimate.
       # tacking on spurious ;'s would enable a hole so we'll be especially
       # careful about those.
       $seq_name =~ s/[\/;]//g;

       my $old_s = $session->Seq({-seq_name=>$seq_name});
       unless ($old_s->db_exists) {
         print $cgi->center("There is no known sequence $seq_name."),$cgi->br,"\n";
         return;
       }

       # see how we're going to re-import.
       my $import_command = '-seq '.$seq_name;
       # do we know exactly which lane it coes from?
       my $assem = $session->Seq_Assembly({-seq_name=>$seq_name,
                                        -src_seq_src=>'phred_seq'});
       if ($assem->db_exists) {
         $assem->select;
         my $phred = $session->Phred_Seq({-id=>$assem->src_seq_id})->select_if_exists;
         if ($phred && $phred->lane_id) {
           $import_command = '-lane_id '.$phred->lane_id;
         }
       }
       # see if we want to process this as a recheck
       $import_command .= ' -recheck' if $old_s->qualifier;

       my $stuff = $session->Seq_AlignmentSet({-seq_name=>$seq_name})->select->delete;
       print $cgi->center("Deleting ".$stuff->count." alignments for $seq_name...."),
             $cgi->br,"\n";

       $stuff = $session->Blast_RunSet({-seq_name=>$seq_name})->select->delete;
       print $cgi->center("Deleting ".$stuff->count." blast runs or $seq_name..."),
             $cgi->br,"\n";

       $stuff = $session->Seq_AssemblySet({-seq_name=>$seq_name}
                                        )->select->delete('seq_name');
       print $cgi->center("Deleting ".$stuff->count.
                          " sequence assembly records for $seq_name..."),
             $cgi->br,"\n";

       print $cgi->center("Deleting sequence for $seq_name..."),
             $cgi->br,"\n";
       $session->Seq({-seq_name=>$seq_name})->select->delete;

       # re-import
       print $cgi->center("Reprocessing sequence $seq_name..."),
             $cgi->br,"\n";
      
       `$PELEMENT_BIN/seqImporter.pl -quiet $import_command`;
        
       if ($old_s->db_exists) {

         # re-blast
         print $cgi->center("Blasting sequence $seq_name..."),
               $cgi->br,"\n";
      
         `$PELEMENT_BIN/runBlast.pl -protocol release3 -quiet $seq_name`;
         `$PELEMENT_BIN/runBlast.pl -protocol release5 -quiet $seq_name`;
         `$PELEMENT_BIN/runBlast.pl -protocol te -quiet $seq_name`;
         `$PELEMENT_BIN/runBlast.pl -protocol vector -quiet $seq_name`;
         `$PELEMENT_BIN/alignSeq.pl -release 3 -quiet $seq_name`;
         `$PELEMENT_BIN/alignSeq.pl -release 5 -quiet $seq_name`;
       } else {
         print $cgi->center("No sequence imported. Blasting not done."),
               $cgi->br,"\n";
       }

       print $cgi->center("Processing complete."),$cgi->br,"\n";

     } elsif ($action eq 'new') {
       print $cgi->center("Processing sequence for $seq_name..."),"\n";
       my $import_command;
       my ($strain,$end,$qual) = Seq::parse($seq_name);
       if ($qual) {
         # this ought not happen
         print $cgi->center("This is not set up to deal with qualified sequences yet.");
         return;
       }
       unless ($strain && ($end eq '3' || $end eq '5')) {
         # this ought not happen
         print $cgi->center("This is only set up to deal with 3' or 5' sequences still.");
         return;
       }

       # be certain there is only 1 sequence
       my $laneSet = $session->LaneSet({-seq_name=>$strain,
                                             -end_sequenced=>$end})->select;
       my $thelane_id;
       if ($laneSet->count > 1 ) {
         # find the earliest
         my $earliest = ($laneSet->as_list)[0];
         map { $earliest = $_ if ($_->run_date cmp $earliest->run_date < 0) } $laneSet->as_list;
         $thelane_id = $earliest->id;
         print $cgi->center("Using earliest lane from ".$earliest->run_date." as reference data.");
       } elsif ($laneSet->count == 0 ) {
         print $cgi->center("Cannot find data for $seq_name.");
         return;
       } else {
         $thelane_id = ($laneSet->as_list)[0]->id;
       }
       $import_command = '-lane_id '.$thelane_id;

       `$PELEMENT_BIN/seqImporter.pl -quiet $import_command`;

       print $cgi->center("Blasting...");
       `$PELEMENT_BIN/runBlast.pl -protocol release3 -quiet $seq_name`;
       `$PELEMENT_BIN/runBlast.pl -protocol release5 -quiet $seq_name`;
       `$PELEMENT_BIN/runBlast.pl -protocol te -quiet $seq_name`;
       `$PELEMENT_BIN/runBlast.pl -protocol vector -quiet $seq_name`;
       print $cgi->center("Aligning...");
       `$PELEMENT_BIN/alignSeq.pl -release 3 -quiet $seq_name`;
       `$PELEMENT_BIN/alignSeq.pl -release 5 -quiet $seq_name`;
       print $cgi->center("Processing completed.");

     } elsif ($action eq 'build') {
       print $cgi->center("Assembling sequence for $seq_name..."),"\n";
       my $build_command;
       my ($strain,$end,$qual) = Seq::parse($seq_name);
       if ($qual) {
         # this ought not happen
         print $cgi->center("This is not set up to deal with qualified sequences yet.");
         return;
       }
       unless ($strain && ($end eq '3' || $end eq '5')) {
         # this ought not happen
         print $cgi->center("This is only set up to deal with 3' or 5' sequences still.");
         return;
       }

       # be certain there are more than 1 sequence
       my $laneSet = $session->LaneSet({-seq_name=>$strain,
                                             -end_sequenced=>$end})->select;
       if ($laneSet->count < 2 ) {
         print $cgi->center("This is not set up to deal with strain with single sequences yet.");
         return;
       } elsif ($laneSet->count == 0 ) {
         print $cgi->center("Cannot find data for $seq_name.");
         return;
       }
       $build_command = "-seq $strain -end $end";

       # we're committed now. get rid of the old
       my $stuff = $session->Seq_AlignmentSet({-seq_name=>$seq_name})->select->delete;
       print $cgi->center("Deleting ".$stuff->count." alignments for $seq_name...."),
             $cgi->br,"\n";

       $stuff = $session->Blast_RunSet({-seq_name=>$seq_name})->select->delete;
       print $cgi->center("Deleting ".$stuff->count." blast runs or $seq_name..."),
             $cgi->br,"\n";

       $stuff = $session->Seq_AssemblySet({-seq_name=>$seq_name}
                                        )->select->delete('seq_name');
       print $cgi->center("Deleting ".$stuff->count.
                          " sequence assembly records for $seq_name..."),
             $cgi->br,"\n";

       print $cgi->center("Reassembling..."),$cgi->br,"\n";
       `$PELEMENT_BIN/buildConsensus.pl -quiet $build_command`;

       print $cgi->center("Blasting..."),$cgi->br,"\n";
       `$PELEMENT_BIN/runBlast.pl -protocol release3 -quiet $seq_name`;
       `$PELEMENT_BIN/runBlast.pl -protocol release5 -quiet $seq_name`;
       `$PELEMENT_BIN/runBlast.pl -protocol te -quiet $seq_name`;
       `$PELEMENT_BIN/runBlast.pl -protocol vector -quiet $seq_name`;
       print $cgi->center("Aligning..."),$cgi->br,"\n";
       `$PELEMENT_BIN/alignSeq.pl -release 3 -quiet $seq_name`;
       `$PELEMENT_BIN/alignSeq.pl -release 5 -quiet $seq_name`;
       print $cgi->center("Processing completed.");

     } elsif ($action eq 'merge') {
       print $cgi->center("we would remerge end sequence for $seq_name."),"\n";

     } else {
       print $cgi->center("no action specified for $seq_name."),"\n";
     }
   } else {
       print $cgi->center("no sequence specified for $seq_name."),"\n";
   }
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
   $bR->query_begin($exon->{from2});
   $bR->query_end($exon->{to2});
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

   my $orient = $cgi->param('orient') || 1;
   print $bR->to_html($cgi,$orient);
   $orient = -1*$orient;
   print $cgi->center($cgi->a({-href=>'assemblyReport.pl?seq_name='.
                                $seq_name.'&id='.$id.'&orient='.$orient,
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
  $strain =~ s/\..*$//g;
  my $s = new Strain($session,{-strain_name=>Seq::strain($strain)});

  if ( !$s->db_exists ) {
     print $cgi->center($cgi->h2("No strain $strain in the db.")),"\n";
     return;
  }

  my $seqSet = new SeqSet($session,{-strain_name=>$s->strain_name})->select;

  my @tableRows = ();

  # we're going to keep track of the ends to report unimported seq
  my %endsCaught;
  foreach my $seq ($seqSet->as_list) {
     my $sAS = new Seq_AssemblySet($session,
                                     {-seq_name=>$seq->seq_name})->select;

     my $info;
     
     my $buildbutton;
     foreach my $sA ($sAS->as_list) {
        # keep track of this
        $endsCaught{Seq::end($sA->seq_name)} = 1;
        if ($sA->src_seq_src eq 'phred_seq') {
           my $linkText = makeLabel($session,$sA->src_seq_id,'phred');
           $info .= $cgi->a({-href=>'seqReport.pl?db=phred_seq&id='.
                                                         $sA->src_seq_id,
                           -target=>'_seq'},$linkText).' assembled '.
                                                        $sA->assembly_date.
                    $cgi->a({-href=>'assemblyReport.pl?seq_name='.
                                        $sA->seq_name.'&id='.$sA->src_seq_id,
                             -target=>"_blast"},
                            ' Show Alignment').$cgi->br;

           if ( $buildbutton ) {
              $buildbutton = $cgi->a({-href=>'assemblyReport.pl?seq_name='.
                                             $sA->seq_name.'&action=build'},
                              ' Rebuild sequence for '.$sA->seq_name);
           } else {
              $buildbutton = $cgi->a({-href=>'assemblyReport.pl?seq_name='.
                                             $sA->seq_name.'&action=import'},
                            ' Reimport sequence for '.$sA->seq_name);
           }

        } elsif ($sA->src_seq_src eq 'seq') {
           my $b = new Seq($session,{-id=>$sA->src_seq_id})->select_if_exists;
           if ($b->seq_name) {
              $info .= $cgi->em('Assembled from '.$b->seq_name).' on '.
                                                $sA->assembly_date.$cgi->br;
           } else {
              $info .= $cgi->em('Assembled from a sequence which '.
                                'has disappered!').$cgi->br;
           }
        } else {
           $info .= $cgi->em('Internal db inconsistency!');
        }
     }

     
     $info = $cgi->em('This sequence assembly not tracked in the database.')
                                                                 unless $info;

     $buildbutton = $cgi->nbsp unless $buildbutton;
        
     push @tableRows, $cgi->td({-align=>'center'},
             [$seq->seq_name]).$cgi->td({-align=>'left'},[$info,$buildbutton]);
  }

  # now track down 3' or 5' flanks not imported if we do not have primary data
   foreach my $end (qw( 3 5)) {
      next if $endsCaught{$end};

      # we do this if we have not identified a phred seq; look for a lane
      my $laneSet = new LaneSet($session,{-seq_name=>$s->strain_name,
                           -end_sequenced=>$end})->select;

      next unless $laneSet->as_list;

      my $info;
      foreach my $lane ($laneSet->as_list) {

         $info .= $cgi->br if $info;

         my $p = new Phred_Seq($session,{-lane_id=>$lane->id})->select;
         if( $p) {
            my $linkText = makeLabel($session,$lane->id,'lane') ||
                                            "Lane Sequence ".$lane->id;
            $info .= $cgi->a({-href=>'seqReport.pl?db=phred_seq&id='.$p->id,
                             -target=>'_seq'},$linkText).' Not imported.';
         } else {
            $info .= "No data available for lane ".$lane->id;
         }
      }
                                                        
      my $seq_name = $s->strain_name.'-'.$end;
  
      my $buildbutton = $cgi->a({-href=>'assemblyReport.pl?seq_name='.
                                            $seq_name.'&action=new'},
                           ' Import sequence for '.$seq_name);
      push @tableRows, $cgi->td({-align=>'center'},
            [$seq_name]).$cgi->td({-align=>'left'},[$info,$buildbutton]);
    
   }
    
    
  $seq_name =~ s/,$/)/;


  print $cgi->center($cgi->h3("Sequence Data Source Tracking For ".
                              "Strain $strain"),$cgi->br),"\n";

  print $cgi->center($cgi->table({-border=>2,-width=>"80%",
                             -bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                  ["Sequence<br>Name","Data Source","Manually<br>Reprocess"] ),
                           @tableRows,
                       ] )
                     )),"\n";

  print $cgi->br,"\n";


  $session->exit;
}

=head1 makeLabel

  A routine for turning something silly (i.e. a phred_seq id) into
  text that makes a better label (i.e. a batch and well location).
  we do this by tracking back from the id into the highest level we
  can.

=cut
sub makeLabel
{
  my $s = shift;
  my $id = shift;
  my $level = shift;
  my $args = shift;

  if ($level eq 'phred' ) {
    my $phredFrom = new Phred_Seq($s,{-id=>$id})->select();
    return makeLabel($s,$phredFrom->lane_id,'lane') || "Phred Sequence ".$id 
                                   if ( $phredFrom && $phredFrom->lane_id);
    return "Phred Sequence $id";
  } elsif ($level eq 'lane') {
    my $laneFrom = new Lane($s,{-id=>$id})->select();
    return unless $laneFrom;
    return makeLabel($s,$laneFrom->gel_id,'gel',$laneFrom->well)  ||
                             "Lane Sequence $id" if $laneFrom->gel_id;
    return "Sequence from file ".$laneFrom->file if $laneFrom->file;
    return "Lane Sequence $id";

  } elsif ($level eq 'gel') {
    my $gelFrom = new Gel($s,{-id=>$id})->select;
    return unless $gelFrom;
    return "Sequence from batch ".
                Processing::batch_id($gelFrom->ipcr_name).":".$args
            if ($gelFrom->ipcr_name && $gelFrom->ipcr_name ne 'untracked');
    return;
  }

  return;

}
