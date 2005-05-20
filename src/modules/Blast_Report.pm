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

use Blast_Run;
use Blast_Hit;
use Blast_HSP;

=head1 insert

   Since the blast report is a view, we need to make this insert happen
   The model 1 Blast_Report insert corresponds to a 1 run, 1 hit and 1 hsp.

=cut
sub insert
{
   my $self = shift;

   my $args = shift || {};
   # there some fields not specified in the blast report view that we
   # need in the run, hit and hsp inserts. These are set to defaults
   # or are passed.

   # are we attaching to an existing blast run? Let's see
   # if the blast run id is set. If not, insert. We're not
   # validating that the run_id really is in the db.
   if (!$self->run_id) {
      my $bRun = new Blast_Run($self->session);
      $bRun->seq_name($self->seq_name);
      $bRun->db($self->db);
      $bRun->date( PCommon::parseArgs($args,'date') || 'now');
      $bRun->program( PCommon::parseArgs($args,'program') || 'blastn');
      $bRun->insert;

      $self->run_id($bRun->id);
   }

   # how about the hit id?
   if (!$self->hit_id) {
      my $bHit = new Blast_Hit($self->session);
      $bHit->run_id($self->run_id);
      $bHit->name($self->name);
      $bHit->insert;

      $self->hit_id($bHit->id);
   }

   # now we really not ought to have an hsp id set
   if (!$self->id ) {
      my $bHsp = new Blast_HSP($self->session);
      $bHsp->hit_id($self->hit_id);
      $bHsp->score($self->score);
      $bHsp->bits($self->bits);
      $bHsp->percent($self->percent);
      $bHsp->match($self->match);
      $bHsp->length($self->length);
   
      $bHsp->query_begin($self->query_begin);
      $bHsp->query_end($self->query_end);
      $bHsp->query_gaps($self->query_gaps);
   
      $bHsp->subject_begin($self->subject_begin);
      $bHsp->subject_end($self->subject_end);
      $bHsp->subject_gaps($self->subject_gaps);
   
      $bHsp->p_val($self->p_val);
      $bHsp->query_align($self->query_align);
      $bHsp->match_align($self->match_align);
      $bHsp->subject_align($self->subject_align);
      $bHsp->strand($self->strand);
   
      $bHsp->insert;

      $self->id($bHsp->id);
   }

   return $self;

}

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
    $s_ctr += $s_inc*(length($s_seg)-1);
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



