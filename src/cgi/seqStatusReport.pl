#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqStatusReport.pl Web report of the batch processing information.

=cut

use Pelement;
use Session;
use Seq;
use SeqSet;
use Blast_RunSet;
use Seq_AssemblySet;
use Seq_AlignmentSet;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>$cgi->param('seq')." Sequence Status Report"});
print $cgi->banner();


if ($cgi->param('seq')) {
   if ($cgi->param('action')) {
      performAction($cgi);
   } else {
      reportSeq($cgi);
   }
} else {
   selectSeq($cgi);
}

print $cgi->footer([{link=>"batchReport.pl",name=>"Batch Report"},
                   {link=>"strainReport.pl",name=>"Strain Report"},
                   {link=>"gelReport.pl",name=>"Gel Report"},
                   {link=>"statusReport.pl",name=>"Status Report"},
                    ]);

print $cgi->close_page();

exit(0);


sub selectSeq
{

   my $cgi = shift;
  
   print
     $cgi->center(
       $cgi->h3("Enter the Sequence Name:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",-action=>"seqStatusReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["Sequence Name",$cgi->textfield(-name=>"seq")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub performAction
{
   my $cgi = shift;

   my $session = new Session({-log_level=>0});
   my $seq;
   if ($cgi->param('seq') ) {
      $seq = new Seq($session,{-seq_name=>$cgi->param('seq')});
   }

   if ( !$seq->db_exists ) {
      print $cgi->center($cgi->h2("No record for Sequence with name ".
                                   $seq->seq_name.".")),"\n";
      return;
   }
   $seq->select;

   if (lc($cgi->param('action')) eq 'delete') {
      $session->log_level($Session::Verbose);
      $session->db_begin;

      # to delete all records of a sequence, we need to delete it from
      # seq, blast_run (there is a cascading delete here), seq_assembly
      # and seq_alignment

      my $bRS = new Blast_RunSet($session,{-seq_name=>$seq->seq_name})->select;
      my $sAsS = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;
      my $sAlS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;
      print $cgi->center("Deleting sequence ".$seq->seq_name,", ",
                         scalar($sAsS->as_list)," assemblies and ",
                         scalar($bRS->as_list)," blast runs and ",
                         scalar($sAlS->as_list)," seq alignments."),"\n";
    
      
      print $cgi->center('Here we would delete this sequence, but these changes are not presently committed.');
      $session->db_rollback;
      return;
   } elsif (lc($cgi->param('action')) eq 'current') {
      print $cgi->center('here we remove the qualifier.');

      # make sure there is not now a current sequence.
      my $currentSeqName = $seq->strain .'-'. $seq->end;
      my $oldS = new Seq($session,{-seq_name=>$currentSeqName});
      if ($oldS->db_exists) {
         print $cgi->center("There is a sequence $currentSeqName in the db marked 'current'. ".
                            "This must be curated before a new sequence can be labeled current.");
         return;
      }
      $session->db_begin;
      my $bRS = new Blast_RunSet($session,{-seq_name=>$seq->seq_name})->select;
      my $sAsS = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;
      my $sAlS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;

      # update all of these records to the new seq name
      foreach my $r ($bRS->as_list, $sAsS->as_list, $sAlS->as_list) {
         $r->seq_name($r->seq_name.'.'.$newNumber);
         $r->update;
      }

      $seq->unique_identifier;
      $seq->seq_name($currentSeqName);
      $seq->update;
 
      $session->db_commit;
      $cgi->param('seq',$seq->seq_name);

   } elsif (lc($cgi->param('action')) eq 'curated') {
      print $cgi->center('here we would rename it to a .letter');
   } elsif (lc($cgi->param('action')) eq 'transitory') {

      # find the highest numbered seq_name
      my $sS = new SeqSet($session,{-like=>{seq_name=>$seq->seq_name.'.%'}})->select;
      my $newNumber = 1;
      foreach my $s ($sS->as_list) {
        next unless $s->seq_name =~ /\.(\d+)$/;
        $newNumber = $1 + 1 if $1 >= $newNumber;
      }
       
      $session->db_begin;

      my $bRS = new Blast_RunSet($session,{-seq_name=>$seq->seq_name})->select;
      my $sAsS = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;
      my $sAlS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;

      # update all of these records to the new seq name
      foreach my $r ($bRS->as_list, $sAsS->as_list, $sAlS->as_list) {
         $r->seq_name($r->seq_name.'.'.$newNumber);
         $r->update;
      }

      $seq->unique_identifier;
      $seq->seq_name($seq->seq_name.'.'.$newNumber);
      $seq->update;
 
      $session->db_commit;
      $cgi->param('seq',$seq->seq_name);
   } else {
      print $cgi->center('Do not know how to treat action '.$cgi->param('action'));
   }

   reportSeq($cgi,$session);
}

sub reportSeq
{
   my $cgi = shift;

   my $session = shift || new Session({-log_level=>0});


   my $seq;
   if ($cgi->param('seq') ) {
      $seq = new Seq($session,{-seq_name=>$cgi->param('seq')});
   }

   if ( !$seq->db_exists ) {
      print $cgi->center($cgi->h2("No record for Sequence with name ".
                                   $seq->seq_name.".")),"\n";
      return;
   }
   $seq->select;


   my $q = $seq->qualifier;

   if ($q =~ /^\d+$/ ) {
      $q = 'transitory';
   } elsif ($q =~ /^r\d+$/ ) {
      $q = 'unconfirmed recheck';
   } elsif ($q = /^[a-z]$/ ) {
      $q = 'curated';
   } else {
      $q = 'current';
   }

   my @tableRows = ();

   push @tableRows, [qq(The sequence may be marked ).$cgi->em('current').
                     qq( and remove the qualifiers. This may only be done
                     if there is not now a sequence of this strain
                     and this end marked current),
                    $cgi->submit(-name=>'action',-value=>'Current')]
                                                      unless $q eq 'current';
   push @tableRows, [qq(The sequence may be marked ).$cgi->em('transitory').
                     qq( if we think it may have been removed geneticly.),
                    $cgi->submit(-name=>'action',-value=>'Transitory')]
                                                     unless $q eq 'transitory';
   push @tableRows, [qq(The sequence may be marked as a ).$cgi->em('curated').
                     qq( sequence of a multiple insertion. Use this designation
                     if the strain has multiple, distinguishable insertions.),
                    $cgi->submit(-name=>'action',-value=>'Curated')]
                                                     unless $q eq 'curated';
   push @tableRows, [qq(The sequence may be removed from the database. ).
                     $cgi->em(qq(Removing the sequence destroys 
                                 all records of the consensus sequence, blast
                                 reports and sequence alignments. Do this
                                 only if we believe the samples are
                                 contaminated or otherwise mistracked.)),
                    $cgi->submit(-name=>'action',-value=>'Delete')];

   print $cgi->center(
          $cgi->start_form(-method=>'get',-action=>'seqStatusReport.pl'),
          $cgi->hidden(-name=>'seq',-value=>$seq->seq_name),
          $cgi->p('The sequence '.$seq->seq_name.' is currently considered '.
                      $cgi->em($q).'.'),
          $cgi->p('This status may be modified to one of the following:'),
          $cgi->table({-border=>2,-width=>"80%",
                       -bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr([map { $cgi->td({-align=>"center"}, $_ ) } @tableRows])),
          $cgi->end_form ),"\n";

   $session->exit();
}
