#!/usr/local/bin/perl -I../modules

=head1 NAME

  setReport.pl Web report of the alignment status for a set of strains

=cut

use Pelement;
use Session;
use Seq;
use SeqSet;
use Strain;
use Seq_AlignmentSet;
use Seq_Alignment;
use PelementCGI;
use PelementDBI;

use strict;

my $cgi = new PelementCGI;
my $strain = $cgi->param('strain');

print $cgi->header();
print $cgi->init_page({-title=>"Strain Set Alignment Report"});
print $cgi->banner();

if ($strain) {
   my @strain = $cgi->param('strain');
   reportSet($cgi,\@strain);
} else {
   selectSet($cgi);
}

print $cgi->footer([
                 {link=>"batchReport.pl",name=>"Batch Report"},
                 {link=>"strainReport.pl",name=>"Strain Report"},
                 {link=>"gelReport.pl",name=>"Gel Report"},
                 {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                  ]);
print $cgi->close_page();

exit(0);

sub selectSet
{

   my $cgi = shift;

   # nothing is given. present a form to type into.
   print
     $cgi->center(
       $cgi->h3("Enter the Strain identifiers, separated by spaces or commas:"),"\n",
       $cgi->start_form(-method=>"get",-action=>"setReport.pl"),"\n",
          $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
             $cgi->Tr( [
              $cgi->td({-colspan=>2},
                    [$cgi->textarea(-name=>"strain",-cols=>40,-rows=>20)]),
              $cgi->td({-align=>'center'},
                  [$cgi->submit(-name=>"Report"),$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
       ),"\n";
}

sub reportSet
{
   my ($cgi,$setRef) = @_;

   my $session = new Session({-log_level=>0});

   my @goodHits = ();
   my @multipleHits = ();
   my @unalignedSeq = ();
   my @badStrains = ();

   # filter the set list to eliminate redundancies, end identiers, punctuation,,

   my %seqSet = ();
   map { map {$seqSet{Seq::strain($_)}=1 unless !$_ || $_ =~ /[,+]/ } split(/\s/,$_) } @$setRef;

   foreach my $strain (keys %seqSet) {

      my $strainLink = $cgi->a(
                 {-href=>"strainReport.pl?strain=".$strain,
                  -target=>"_strain"}, $strain);
      my $seqS = new SeqSet($session,{-strain_name=>$strain})->select;
      if (!$seqS->as_list) {
         push @badStrains, [$strain];
         next;
      }

      foreach my $seq ($seqS->as_list) {
         my $seqAS = new Seq_AlignmentSet($session,{-seq_name=>$seq->seq_name})->select;
         if (!scalar($seqAS->as_list)) {
            push @unalignedSeq , [$strainLink,$seq->seq_name,length($seq->sequence)];
            next;
         }

         # we'll go through this list looking for things other than muliples
         my $gotAHit = 0;
         foreach my $seqA ($seqAS->as_list) {
            if ($seqA->status ne 'multiple' ) {
               if ( $gotAHit ) {
                  push @goodHits,
                       [$strainLink,$seq->seq_name,$seqA->scaffold,$seqA->s_insert,
                             ($seqA->p_end>$seqA->p_start)?+1:-1,$seqA->status." TROUBLE"];
               } else {
                  $gotAHit = 1;
                  (my $arm = $seqA->scaffold) =~ s/arm_//;
                  push @goodHits,
                       [$strainLink,$seq->seq_name,$arm,$seqA->s_insert,
                             ($seqA->p_end>$seqA->p_start)?+1:-1,$seqA->status];
               }
            }
         }

         push @multipleHits ,[$strainLink,$seq->seq_name] if !$gotAHit;
      }


   }

   if ( @goodHits ) {
      @goodHits = sort { $a->[1] cmp $b->[1] } @goodHits;
      print $cgi->center($cgi->h3("Sequence Alignments"),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain","Sequence<br>Name","Scaffold",
                       "Location","Strand","Status"] ),
                           (map { $cgi->td({-align=>"center"}, $_ ) } @goodHits),
                       ] )
                     )),$cgi->br,$cgi->hr({-width=>'70%'}),"\n";
   } else {
      print $cgi->center($cgi->h3("No Sequence Alignments for this set."),$cgi->br),$cgi->hr({-width=>'70%'}),"\n",
   }

   if (@unalignedSeq) {

      @unalignedSeq = sort { $b->[2] <=> $a->[2] } @unalignedSeq;
      print $cgi->center($cgi->h3("Unaligned Sequences"),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain","Sequence<br>Name","Sequence<br>Length"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @unalignedSeq),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'50%'}),"\n";
   }

   if ( @multipleHits ) {

      @multipleHits = sort { $a->[1] cmp $b->[1] } @multipleHits;
      print $cgi->center($cgi->h3("Sequences With Multiple Hits"),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain","Sequence<br>Name"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @multipleHits),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'50%'}),"\n";
   
   }

   if ( @badStrains ) {
      @badStrains = sort { $a->[0] cmp $b->[0] } @badStrains;
      print $cgi->center($cgi->h3("Strains not in the DB"),$cgi->br),"\n",
         $cgi->center($cgi->table({-border=>2,-width=>"80%",-bordercolor=>$HTML_TABLE_BORDERCOLOR},
           $cgi->Tr( [
              $cgi->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR},
                      ["Strain"] ),
                       (map { $cgi->td({-align=>"center"}, $_ ) } @badStrains),
                      ] )
                     )),$cgi->br,$cgi->hr({-width=>'30%'}),"\n";
   }
 

   my $setLink = join('+',@$setRef);
   $setLink =~ s/ /+/g;

   print $cgi->br,
         $cgi->html_only($cgi->a({-href=>"setReport.pl?strain=$setLink&format=text"},
                  "View Report on this set as Tab delimited list."),$cgi->br,"\n"),
         $cgi->html_only($cgi->a({-href=>"setReport.pl?strain=$setLink"},
                  "Refresh Report on this set."),$cgi->br,"\n");
  $session->exit();
}
