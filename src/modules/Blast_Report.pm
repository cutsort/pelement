=head1 Name

   Blast_Report.pm   A module for the db interface for Blast_Report thingies.

=head1 Usage

   use Blast_Report;
   $blast_Report = new Blast_Report([options]);

=cut

package Blast_Report;

use strict;
use DbObject;
use PelementCGI;

=head1 to_html

   create a html formatted view of the blast alignment in a form
   suitable for a webpage.

   a handle on a cgi object is required; an optional orientation
   (+/- 1) sets the forward/reverse view.

=cut

sub to_html
{

  my $self = shift;
  my $cgi = shift;
  my $orient = shift || 1;
  
  my $strand = $self->strand;
  my $query_begin = $self->query_begin;
  my $query_end = $self->query_end;
  my $subject_begin = $self->subject_begin;
  my $subject_end = $self->subject_end;

  my $query_align = $self->query_align;
  my $subject_align = $self->subject_align;
  my $match_align = $self->match_align;

  if( $orient == '-1') {
    $strand = -1*$strand;
    ($query_begin,$query_end) = ($query_end,$query_begin);
    ($subject_begin,$subject_end) = ($subject_end,$subject_begin);
    foreach my $seq ($query_align,$subject_align,$match_align) {
       $seq = _revcomp($seq);
    }
  }

  $strand = ($strand==-1)?"Minus":"Plus";

  my $rS;

  $rS .= "<pre>\n";

  $rS .= ">".$self->name."\n\n";

  $rS .= "    $strand Strand HSP:\n\n";
  $rS .= "  Score = ".$self->score." (".$self->bits." bits), P = ".
         $self->p_val."\n";
  $rS .= "  Identities = ".$self->match."/".$self->length." (".
         $self->percent."%), Positives = ".$self->match."/".
         $self->length." (".$self->percent."%),";
  $rS .= " Strand = $strand / ".(($orient>0)?"Plus":"Minus")."\n\n";

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
    $rS .= sprintf("Query: %${field_width}d $q_seg",$q_ctr);
    $q_seg =~ s/-//g;
    $q_ctr += $q_inc*(length($q_seg)-1);
    $rS .= sprintf(" %${field_width}d\n",$q_ctr);
    $q_ctr += $q_inc;
    $rS .= sprintf("       %${field_width}s $m_seg\n"," ");
    $rS .= sprintf("Sbjct: %${field_width}d $s_seg",$s_ctr);
    $s_seg =~ s/-//g;
    $s_ctr += $s_inc*length($s_seg)-1;
    $rS .= sprintf(" %${field_width}d\n\n",$s_ctr);
    $s_ctr += $s_inc;
  }
 
  $rS .= "</pre>\n";


  return $rS;

}

sub _revcomp
{
  my $seq = shift;
  $seq = join('',reverse(split(//,$seq)));
  $seq =~ tr/ACGTacgt/TGCAtgca/;
  return $seq;
}

1;



