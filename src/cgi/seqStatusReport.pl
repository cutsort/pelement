#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

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
print $cgi->init_page({-title=>$cgi->param('seq')." Sequence Status Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();


if ($cgi->param('seq')) {
   if ($cgi->param('action')) {
      performAction($cgi);
      print $cgi->center($cgi->a({-href=>'strainReport.pl?strain='.
                         $cgi->param('seq')},'Return to Strain Report'));
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

      # this must be in a transaction 
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
    
      
      map { $_->delete } $sAlS->as_list;
      map { $_->delete } $bRS->as_list;
      map { $_->unique_identifier; $_->delete; } $sAsS->as_list;
      map { $_->delete } $sAsS->as_list;
      $seq->delete;

      $session->db_commit;
      return;
   } elsif (lc($cgi->param('action')) eq 'current') {

      # make sure there is not now a current sequence.
      my $currentSeqName = $seq->strain .'-'. $seq->end;
      my $oldS = new Seq($session,{-seq_name=>$currentSeqName});
      if ($oldS->db_exists) {
         print $cgi->center("There is a sequence $currentSeqName in the db marked 'current'. ".
                            "This must be curated before a new sequence can be labeled current.");
         return;
      }

      updateSeqRecords($session,$seq,$currentSeqName);

      $cgi->param('seq',$seq->seq_name);

   } elsif (lc($cgi->param('action')) eq 'curated') {
      my $sS = new SeqSet($session,{-strain_name=>$seq->strain_name})->select;
      my $letter;
      my $baseStrain = $seq->strain_name;
      map {  my $this_strain = $_->strain;
             if ($this_strain =~/${baseStrain}([a-z])$/ ) {
               $letter  = $1 if ord($1) > ord($letter) && $_->end eq $seq->end;
             } } $sS->as_list;
      if ($letter) {
         (print $cgi->center("We cannot have more than 26 insertions!") and return) if $letter eq 'z';
        $letter = chr(ord($letter)+1);
      } else {
        $letter = 'a';
      }
      my $new_name = $baseStrain.$letter;
      $new_name .= '-'.$seq->end if $seq->end =~ /[35]/;

      # make sure there is not one of these already
      if ( new Seq($session,{-seq_name=>$new_name})->db_exists) {
         print $cgi->center("There is already a sequence named $new_name.");
      } else {
         print $cgi->center("Update sequence name to $new_name.");
         updateSeqRecords($session,$seq,$new_name);
      }

      $cgi->param('seq',$seq->seq_name);
      
   } elsif (lc($cgi->param('action')) eq 'transitory') {

      # find the highest numbered seq_name
      my $unqualified_seq = $seq->strain.'-'.$seq->end;
      my $sS = new SeqSet($session,{-like=>{seq_name=>$unqualified_seq.'.%'}})->select;
      my $newNumber = 1;
      foreach my $s ($sS->as_list) {
        next unless $s->seq_name =~ /\.(\d+)$/;
        $newNumber = $1 + 1 if $1 >= $newNumber;
      }
       
      updateSeqRecords($session,$seq,$unqualified_seq.'.'.$newNumber);
      $cgi->param('seq',$seq->seq_name);

   } else {
      print $cgi->center('Do not know how to treat action '.$cgi->param('action'));
   }

   reportSeq($cgi,$session);
}

sub updateSeqRecords
{
   my $session = shift;
   my $seq = shift;
   my $new_name = shift;

   $session->db_begin;

   my $bRS = new Blast_RunSet($session,{-seq_name=>$seq->seq_name})->select;
   my $sAsS = new Seq_AssemblySet($session,{-seq_name=>$seq->seq_name})->select;
   my $sAlS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;

   # update all of these records to the new seq name
   foreach my $r ($bRS->as_list, $sAsS->as_list, $sAlS->as_list) {
      $r->unique_identifier;
      $r->seq_name($new_name);
      $r->update;
   }

   # now update the seq
   $seq->unique_identifier;
   $seq->seq_name($new_name);
   $seq->update;

   $session->db_commit;
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
   } elsif ($q =~ /^i\d+$/ ) {
      $q = 'reference imported'; # can't touch this
   } elsif ($q = /^[a-z]$/ ) {
      $q = 'curated';
   } else {
      $q = 'current';
   }

   my @tableRows = ();

   unless ($q eq 'reference imported') {

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
   }
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
