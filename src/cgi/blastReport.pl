#!/usr/local/bin/perl -I../modules

=head1 NAME

  blastReport.pl Web report of the blast HSP information

=cut

use Pelement;
use PelementCGI;
use Session;
use PelementDBI;
use Blast_Report;


$cgi = new PelementCGI;
my $hsp_id = $cgi->param('id');
my $orient = $cgi->param('orient') || '1';

print $cgi->header;
print $cgi->init_page({-title=>"Blast Report"});
print $cgi->banner;


if ($hsp_id) {
   reportHSP($cgi,$hsp_id,$orient);
} else {
   selectHSP($cgi);
}

print $cgi->footer;
print $cgi->close_page;

exit(0);


sub selectHSP
{

  my $cgi = shift;
  
  print
    $cgi->center(
       $cgi->h3("Enter the Blast HSP Identifier:"),"\n",
       $cgi->br,
       $cgi->start_form(-method=>"get",
                          -action=>"/cgi-bin/pelement/blastReport.pl"),"\n",
          $cgi->table(
             $cgi->Tr( [
                $cgi->td({-align=>"right",-align=>"left"},
                                    ["ID:",$cgi->textfield(-name=>"id")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                    [$cgi->submit(-name=>"Report")]),
                $cgi->td({-colspan=>2,-align=>"center"},
                                    [$cgi->reset(-name=>"Clear")]) ]
             ),"\n",
          ),"\n",
       $cgi->end_form(),"\n",
    ),"\n";
}

sub reportHSP
{
  my $cgi = shift;
  my $id = shift;
  my $orient = shift;

  my $session = new Session({-log_level=>0});
  my @values = ();
  my $bR = new Blast_Report($session,{-id=>$id})->select;
  #my $sql = qq(select seq_name,db,name,score,bits,percent,match,length,
  #                    query_begin,query_end,subject_begin,subject_end,
  #                    query_gaps,subject_gaps,p_val,query_align,match_align,
  #                    subject_align,strand from blast_report where id=$id);
  #
  #$session->db->select($sql,\@values);

  my %db_name = ( release3_genomic => "Release 3 Genomic",
                  na_te.dros       => "Transposable Elements",
                );
  my %subject_name = ( arm_2L => "2L",
                       arm_2R => "2R",
                       arm_3L => "3L",
                       arm_3R => "3R",
                       arm_X  => "X",
                       arm_4  => "4");

  #my ($seq_name,$db,$name,$score,$bits,$percent,$match,$length,
  #    $query_begin,$query_end,$subject_begin,$subject_end,
  ##    $query_gaps,$subject_gaps,$p_val,$query_align,
  #    $match_align,$subject_align,$strand) = @values;

  my $strand = $bR->strand;
  my $query_begin = $bR->query_begin;
  my $query_end = $bR->query_end;
  my $subject_begin = $bR->subject_begin;
  my $subject_end = $bR->subject_end;

  my $query_align = $bR->query_align;
  my $subject_align = $bR->subject_align;
  my $match_align = $bR->match_align;

  if( $orient == '-1') {
    $strand = -1*$strand;
    ($query_begin,$query_end) = ($query_end,$query_begin);
    ($subject_begin,$subject_end) = ($subject_end,$subject_begin);
    foreach my $seq ($query_align,$subject_align,$match_align) {
       $seq = revcomp($seq);
    }
  }

sub revcomp
{
  my $seq = shift;
  $seq = join('',reverse(split(//,$seq)));
  $seq =~ tr/ACGTacgt/TGCAtgca/;
  return $seq;
}
    

  $strand = ($strand==-1)?"Minus":"Plus";
  print $cgi->center(
        $cgi->h3("Blast Hit for sequence ",$bR->seq_name),$cgi->br),"\n";

  print "<pre>\n";


  print ">".$bR->name."\n\n";

  print "    $strand Strand HSP:\n\n";
  print "  Score = ".$bR->score." (".$bR->bits." bits), P = ".$bR->p_val."\n";
  print "  Identities = ".$bR->match."/".$bR->length." (".$bR->percent.
        "%), Positives = ".$bR->match."/".$bR->length." (".$bR->percent."%),";
  print " Strand = $strand / ".(($orient>0)?"Plus":"Minus")."\n\n";

  my $field_width = (sort { $a <=> $b }
             ($query_begin,$query_end,$subject_begin,$subject_end))[-1];
  $field_width = int(1+log($field_width)/log(10.));
  

  my ($q_inc,$s_inc);
  my $s_ctr = $subject_begin;
  my $q_ctr = $query_begin;

  if ($query_begin<$query_end) {
     $q_inc = +1;
  } else {
     $q_inc = -1;
  }

  if ($subject_begin<$subject_end) {
     $s_inc = +1;
  } else {
     $s_inc = -1;
  }

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
    printf "       %${field_width}s $m_seg\n"," ";
    printf "Sbjct: %${field_width}d $s_seg",$s_ctr;
    $s_seg =~ s/-//g;
    $s_ctr += $s_inc*length($s_seg)-1;
    printf " %${field_width}d\n\n",$s_ctr;
    $s_ctr += $s_inc;
  }
 
  print "</pre>\n";

  $n = -1*$orient;
  print $cgi->center($cgi->a({-href=>"blastReport.pl?id=$id&orient=$n"},
        "Reverse Complement")),"\n";

  $session->exit();
}
