#!/usr/local/bin/perl -I../modules

=head1 NAME

  strainReport.pl Web report of the strain information.

=cut

use Pelement;
use PelementCGI;
use Session;
use PelementDBI;


$::cgi = new PelementCGI;
my $strain = $cgi->param('strain');

print $::cgi->header();
print $::cgi->init_page();
print $::cgi->banner();


if ($strain) {
   reportStrain($strain);
} else {
   selectStrain();
}

print $cgi->footer();
print $cgi->close_page();

exit(0);


sub selectStrain
{
  
  print
    $::cgi->center(
       $::cgi->h3("Enter the Strain Name:"),"\n",
       $::cgi->br,
       $::cgi->start_form(-method=>"get",-action=>"strainReport.pl"),"\n",
          $::cgi->table( 
             $::cgi->Tr( [
                $::cgi->td({-align=>"right",-align=>"left"},
                                    ["Strain:",$::cgi->textfield(-name=>"strain")]),
                $::cgi->td({-colspan=>2,-align=>"center"},[$::cgi->submit(-name=>"Report")]),
                $::cgi->td({-colspan=>2,-align=>"center"},[$::cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $::cgi->end_form(),"\n",
    ),"\n";
}

sub reportStrain
{
  my $strain = shift;

  my $session = new Session({-log_level=>0});
  my @values = ();
  my $sql = qq(select seq_name,insertion_pos,sequence from seq where strain_name='$strain'
               order by seq_name desc);

  $session->db->select($sql,\@values);

  if ( !@values) {
     print $::cgi->center($::cgi->h2("No flanking sequence for strain $strain.")),"\n";
     return;
  }


  my %db_name = ( "release3_genomic" => "Release 3<br>Genomic",
                  "na_te.dros"       => "Transposable<br>Elements",
                );
  my %subject_name = ( arm_2L => "2L",
                       arm_2R => "2R",
                       arm_3L => "3L",
                       arm_3R => "3R",
                       arm_X  => "X",
                       arm_4  => "4");

  my $seq_names = '(';
  my @tableRows = ();

  while (@values) {
     my ($a,$b,$c) = splice(@values,0,3);
     $c =~ s/(.{50})/$1<br>/g;
     $c = "<tt>".$c."</tt>";
     push @tableRows, [$a,$b,$c];
     $seq_names .= "'$a',";
  }
  $seq_names =~ s/,$/)/;


  print $::cgi->center($::cgi->h3("Flanking sequence for strain $strain"),$cgi->br),"\n";

  print $::cgi->center($::cgi->table({-border=>2,-width=>"80%",-bordercolor=>"#000000"},
           $::cgi->Tr( [
              $::cgi->th( ["Sequence<br>Name","Insert<br>Position","Sequence"] ),
                           (map { $::cgi->td({-align=>"left"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";

  print $::cgi->br,"\n";

  print $::cgi->center($::cgi->h3("Blast HSPs for Flanking Sequences"),$cgi->br),"\n";

  my @values = ();
  my $sql = qq(select seq_name,db,name,subject_begin,subject_end,score,match,
               length,percent,id from blast_report where
               seq_name in ).$seq_names.qq(order by seq_name desc,db,score desc);

  $session->db->select($sql,\@values);
  my @tableRows = ();

  while (@values) {
     my ($a,$b,$c,$d,$e,$f,$g,$h,$i,$j) = splice(@values,0,10);
     $b = $db_name{$b} if exists($db_name{$b});
     $c = $subject_name{$c} if exists($subject_name{$c});
     $detailLink = "<a href=\"blastReport.pl?id=".$j."\" target=\"_blast\">Blast Details</a>";
     $alignLink = "<a href=\"strainReport.pl?id=".$j."&action=align\">Align</a>";
     push @tableRows, [$a,$b,$c,$d."-".$e,$g."/".$h." (".$i."%)",$detailLink,$alignLink];
  }

  print $::cgi->center($::cgi->table({-bordercolor=>"#000000",-border=>2,-width=>"95%"},
           $::cgi->Tr( [
              $::cgi->th( ["Sequence<br>Name","Blast<br>Database","Subject","Range",
                            "Matches","Alignment","Generate<br>Alignment"] ),
                           (map { $::cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";

  print $::cgi->br,"\n";

  print $::cgi->center($::cgi->h3("Sequence alignments"),$cgi->br),"\n";

  my $sql = qq(select id,seq_name,p_start,p_end,scaffold,s_start,s_end,s_insert,status from
               seq_alignment where
               seq_name in ).$seq_names.qq(order by seq_name desc,scaffold,status desc);

  $session->db->select($sql,\@values);
  my @tableRows = ();

  while (@values) {
     my ($a,$b,$c,$d,$e,$f,$g,$h,$i) = splice(@values,0,9);
     my $strand = ($d>$e)?"+":"-";
     my $p_range = ($c>$d)?$d."-".$c:$c."-".$d;
     $e = $subject_name{$e} if exists($subject_name{$e});
     my $link;
     if ($i eq "unique" || $i eq "curated") {
        $link = "<a href=\"alignReport.pl?id=".$a.
                         "&action=ignore\">Disregard</a>";
     } elsif ($i eq "multiple" || $i eq "ignore") {
        $link = "<a href=\"alignReport.pl?id=".$a.
                         "&action=accept\">Accept</a>";
     }

     push @tableRows, [$b,$p_range,$e,$strand,$f."-".$g,$h,$i,$link];
  }
  print $::cgi->center($::cgi->table({-border=>2,-width=>"80%",-bordercolor=>"#000000"},
           $::cgi->Tr( [
              $::cgi->th( ["Sequence<br>Name","Flanking<br>Range","Subject","Strand",
                           "Subject<br>Range","Insertion<br>Position","Status",
                           "Alignment<br>Curation"] ),
                           (map { $::cgi->td({-align=>"center"}, $_ ) } @tableRows),
                       ] )
                     )),"\n";

  $session->exit();
}
