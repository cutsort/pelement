#!/usr/bin/env perl
use FindBin::libs qw(base=modules realbin);

=head1 NAME

  regionImage.pl

=head1 DESCRIPTION 

  The guts of a region image maker. This is normally used as a back end script

=cut

use Pelement;
use Session;
use strict;

use ChadoGeneModelSet;
use CGI::FormBuilder;

# graphics
use Bio::Graphics;
use Bio::SeqFeature::Generic;
use Bio::SeqFeature::Gene::Transcript;
use Bio::SeqFeature::Gene::Exon;

my $form = new CGI::FormBuilder( header=>0,
                                 method=>'GET');

$form->field(name=>'scaffold',type=>'hidden');
$form->field(name=>'center',type=>'hidden');
$form->field(name=>'range',type=>'hidden');
$form->field(name=>'format',type=>'hidden');
$form->field(name=>'release',type=>'hidden');

if ($form->param('scaffold') && $form->param('center') && $form->param('range') && $form->param('release') ) {
  drawImageScaffold($form->param('scaffold'),$form->param('center'),$form->param('range'),$form->param('release'),$form->param('format'));
}

exit(0);

sub drawImageScaffold
{
  my $scaffold = shift;
  my $center = shift || return;
  my $range = shift || 5000;
  my $release = shift || 3;
  my $format = shift || 'png';

  my $session = new Session({-log_level=>0});

  # add the arm_ prefix if need be.
  map { $scaffold = 'arm_'.$scaffold if $scaffold eq $_ } qw(2L 2R 3L 3R 4 X);
  my $insHits = $session->Seq_AlignmentSet({-scaffold=>$scaffold,
                                            -seq_release => $release,
                                            -greater_than=>{s_insert=>$center-$range},
                                            -less_than=>{s_insert=>$center+$range}} )->select;

  # now take it off.
  $scaffold =~ s/^arm_//;

  # the extremes
  my $start_pos = $center - $range;
  my $end_pos = $center + $range;
  
  my $panel = new Bio::Graphics::Panel(
                 -offset    => $start_pos,
                 -start     => $start_pos,
                 -stop      => $end_pos,
                 -pad_left  => 10,
                 -pad_right => 10,
                 -width     => 800);

  my $axis = new Bio::SeqFeature::Generic(-start=>$start_pos,
                                          -end=>$end_pos);
  $axis->display_name($scaffold);

  $panel->add_track($axis,-glyph => 'arrow',
                           -tick => 2,
                         -double => 1,
                          -label => 1);

  my $plus_genes = $panel->unshift_track(-glyph => 'transcript',
                                   -bump  => -1,
                                   -fgcolor => '#332277',
                                   -bgcolor => '#332277',
                                   -label => 1);

  my $plus_inserts = $panel->unshift_track(-glyph => 'pinsertion',
                                      -bump => -1,
                                      -label => 1);

  my $minus_genes = $panel->add_track(-glyph => 'transcript',
                                   -bump  => +1,
                                   -fgcolor => '#332277',
                                   -bgcolor => '#332277',
                                   -label => 1);

  my $minus_inserts = $panel->add_track(-glyph => 'pinsertion',
                                      -bump  => 1,
                                      -label => 1);

  foreach my $s ($insHits->as_list) {

    next unless ($s->status eq 'curated' || $s->status eq 'unique');
    next unless ($s->seq_release eq '3');
    my $strand = (($s->p_start < $s->p_end) eq ($s->s_start < $s->s_end))?+1:-1;
    my $feature = new Bio::SeqFeature::Generic(
                                     -display_name=>$s->seq_name,
                                     -start=>$s->s_insert,
                                     -end=>$s->s_insert);
    $feature->display_name($s->seq_name);
    if ($strand == +1) {
      $feature->strand(+1);
      $plus_inserts->add_feature($feature);
    } else {
      $feature->strand(-1);
      $minus_inserts->add_feature($feature);
    }
  }


  # get the genes
  #my $chado_session = new Session({-log_level=>0,-dbistr=>'dbi:Pg:dbname=chacrm_4_2;host=mastermind.lbl.gov'});
  #my $chado = new ChadoGeneModelSet($chado_session,$scaffold,$start_pos,$end_pos)->select;
  #$chado_session->exit;
  my $chado = $session->GeneModelSet($scaffold.'.rel'.$release,$start_pos,$end_pos)->select;

  # repackage these to group the exons into transcripts.
  my %models;
  foreach my $exon ($chado->as_list) {
    unless ( exists($models{$exon->transcript_name}) ) {
      $models{$exon->transcript_name} = {start=>$exon->start_pos, end=>$exon->end_pos,
                                    strand=>$exon->strand, exons=>[[$exon->start_pos,$exon->end_pos]] };
    } else {
      $models{$exon->transcript_name}->{start} = $exon->start_pos if $exon->start_pos < $models{$exon->transcript_name}->{start};
      $models{$exon->transcript_name}->{end} = $exon->end_pos if $exon->end_pos > $models{$exon->transcript_name}->{end};
      push @{$models{$exon->transcript_name}->{exons}}, [$exon->start_pos,$exon->end_pos];
    }
  }
      

  foreach my $g ( keys %models ) {
    my $gene = new Bio::SeqFeature::Gene::Transcript(-start=>$models{$g}->{start},-end=>$models{$g}->{end});
    foreach my $e ( @{$models{$g}->{exons}} ) {
      $gene->add_sub_SeqFeature(new Bio::SeqFeature::Gene::Exon(-start=>$e->[0],-end=>$e->[1]),'EXPAND');
    }
    $gene->display_name($g);
    if ($models{$g}->{strand} > 0 ) {
      $gene->strand(+1);
      $plus_genes->add_feature($gene);
    } else {
      $gene->strand(-1);
      $minus_genes->add_feature($gene);
    }
  }
  

  if ($format eq 'png') {
    print "Content-type: image/png\n\n";
    print $panel->png;
  } elsif ($format eq 'map') {
    print "Content-type: text/html\n\n";
    print "<html><body><map name=\"themap\">\n";
    my @boxes = $panel->boxes;
    map { print '<area coords="'.$_->[1].','.$_->[2].','.$_->[3].','.$_->[4].'" href="strainReport.pl" />'."\n" } @boxes;
    print "</map></body></html>\n";
  }

  $session->exit;

}
