#!/usr/local/bin/perl -I../modules

=head1 NAME

  blastReport.pl Web report of the blast HSP information

=cut

use Pelement;
use PelementCGI;
use Session;
use PelementDBI;


$::cgi = new PelementCGI;
my $hsp_id = $cgi->param('id');

print $::cgi->header;
print $::cgi->init_page;
print $::cgi->banner;


if ($hsp_id) {
   reportHSP($hsp_id);
} else {
   selectHSP();
}

print $::cgi->footer;
print $::cgi->end_page;

exit(0);


sub selectHSP
{
  
  print
    $::cgi->center(
       $::cgi->h3("Enter the Blast HSP Identifier:"),"\n",
       $::cgi->br,
       $::cgi->start_form(-method=>"get",-action=>"/cgi-bin/pelement/blastReport.pl"),"\n",
          $::cgi->table(
             $::cgi->Tr( [
                $::cgi->td({-align=>"right",-align=>"left"},
                                    ["ID:",$::cgi->textfield(-name=>"id")]),
                $::cgi->td({-colspan=>2,-align=>"center"},[$::cgi->submit(-name=>"Report")]),
                $::cgi->td({-colspan=>2,-align=>"center"},[$::cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $::cgi->end_form(),"\n",
    ),"\n";
}

sub reportHSP
{
  my $id = shift;

  my $session = new Session({-log_level=>0});
  my @values = ();
  my $sql = qq(select seq_name,db,name,score,bits,percent,match,length,
                      query_begin,query_end,subject_begin,subject_end,
                      query_gaps,subject_gaps,p_val,query_align,match_align,
                      subject_align,strand from blast_report where id=$id);

  $session->db->select($sql,\@values);

  my %db_name = ( release3_genomic => "Release 3 Genomic",
                  na_te.dros       => "Transposable Elements",
                );
  my %subject_name = ( arm_2L => "2L",
                       arm_2R => "2R",
                       arm_3L => "3L",
                       arm_3R => "3R",
                       arm_X  => "X",
                       arm_4  => "4");

  my ($seq_name,$db,$name,$score,$bits,$percent,$match,$length,
      $query_begin,$query_end,$subject_begin,$subject_end,
      $query_gaps,$subject_gaps,$p_val,$query_align,
      $match_align,$subject_align,$strand) = @values;


  $strand = ($strand==-1)?"Minus":"Plus";
  print $::cgi->center($::cgi->h3("Blast Hit for sequence $seq_name"),$cgi->br),"\n";

  print "<pre>\n";


  print ">$name\n\n";

  print "    $strand Strand HSP:\n\n";
  print "  Score = $score ($bits bits), P = $p_val\n";
  print "  Identities = $match/$length ($percent%), Positives = $match/$length ($percent%),";
  print " Strand = $strand / Plus\n\n";

  my $field_width = (sort { $a <=> $b } ($query_begin,$query_end,$subject_begin,$subject_end))[-1];
  $field_width = int(1+log($field_width)/log(10.));
  

  my ($q_ctr,$s_ctr,$q_inc);
  if ($strand eq "Plus") {
     $q_ctr = $query_begin;
     $q_inc = +1;
  } else {
     $q_ctr = $query_begin;
     $q_inc = -1;
  }
  $s_ctr = $subject_begin;

  while ($query_align) {
    my $q_seg = substr($query_align,0,60);
    my $m_seg = substr($match_align,0,60);
    my $s_seg = substr($subject_align,0,60);
    substr($query_align,0,60) = '';
    substr($match_align,0,60) = '';
    substr($subject_align,0,60) = '';
    printf "Query: %${field_width}d $q_seg",$q_ctr;
    $q_seg =~ s/-//g;
    $q_ctr += $q_inc*(length($q_seg)-1);
    printf " %${field_width}d\n",$q_ctr;
    $q_ctr += $q_inc;
    printf  "       %${field_width}s $m_seg\n"," ";
    printf "Sbjct: %${field_width}d $s_seg",$s_ctr;
    $s_seg =~ s/-//g;
    $s_ctr += length($s_seg)-1;
    printf " %${field_width}d\n\n",$s_ctr;
    $s_ctr++;
  }
 
  print "</pre>\n";
  $session->exit();
}
