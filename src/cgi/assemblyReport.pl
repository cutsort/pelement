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
use Seq_AssemblySet;
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
           $info .= $cgi->a({-href=>'seqReport.pl?id='.$sA->src_seq_id,
                           -target=>'_seq'},"Phred Sequence ".$sA->src_seq_id).' assembled '.$sA->assembly_date.$cgi->br;

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
