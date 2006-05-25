package RegionImage;

use Pelement;
use Session;
use strict;

use ChadoGeneModelSet;

# graphics
use Bio::Graphics;
use Bio::SeqFeature::Generic;
use Bio::SeqFeature::Gene::Transcript;
use Bio::SeqFeature::Gene::Exon;

sub makePanel
{
  my $scaffold = shift;
  my $center = shift || return;
  my $range = shift || 5000;
  my $rel = shift || 3;
  my $showall = shift || 0;

  my $session = new Session({-log_level=>0});

  # add the arm_ prefix if need be.
  map { $scaffold = 'arm_'.$scaffold if $scaffold eq $_ } qw(2L 2R 3L 3R 4 X);
  my $insHits = $session->Seq_AlignmentSet(
                             {-scaffold => $scaffold,
                           -seq_release => $rel,
                          -greater_than => {s_insert=>$center-$range},
                             -less_than => {s_insert=>$center+$range}} )->select;

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
                                      -label => 1,
                                      -bgcolor => \&colorCallback);

  my $minus_genes = $panel->add_track(-glyph => 'transcript',
                                   -bump  => +1,
                                   -fgcolor => '#332277',
                                   -bgcolor => '#332277',
                                   -label => 1);

  my $minus_inserts = $panel->add_track(-glyph => 'pinsertion',
                                      -bump  => 1,
                                      -label => 1,
                                      -bgcolor => \&colorCallback);


  # we're going to look at the features ahead of inserting them in the
  # panel in order to remove redunancies
  my %featureHash;

  foreach my $s ($insHits->as_list) {

    next unless ($s->status eq 'curated' || $s->status eq 'unique');
    next unless ($s->seq_release eq $rel);
    my $status = 'other';

    # juuust in case we cannot identify the strain.
    my $strain_name = '';
    my $seq = $session->Seq({-seq_name=>$s->seq_name})->select_if_exists;
    if ($seq && $seq->strain_name) {
      $strain_name = $seq->strain_name;
      my $strain = $session->Strain({-strain_name=>$seq->strain_name})->select_if_exists;
      if ($strain && $strain->status) {
        $status = $strain->status;
      }
    }

    next unless $status eq 'permanent' || $status eq 'new' || $showall;
     
    my $strand = (($s->p_start < $s->p_end) eq ($s->s_start < $s->s_end))?+1:-1;
    my $feature = new Bio::SeqFeature::Generic(
                                     -display_name=>$s->seq_name,
                                     -start=>$s->s_insert,
                                     -end=>$s->s_insert,
                                     -tag=>{status=>$status});
    $feature->display_name($s->seq_name);
   
    if ($strand == +1) {
      $feature->strand(+1);
      ##$plus_inserts->add_feature($feature);
    } else {
      $feature->strand(-1);
      ##$minus_inserts->add_feature($feature);
    }
    push @{$featureHash{$strain_name}}, $feature;
  }

  # now look over the feature, merging consistent ones
  foreach my $s (keys %featureHash) {
    if ($s && scalar(@{$featureHash{$s}}) == 1 ) {
      # a single insertion. use it
      my $f = $featureHash{$s}->[0];
      if ($f->strand > 0) {
        $plus_inserts->add_feature($f);
      } else {
        $minus_inserts->add_feature($f);
      }
    } else {
      my $min_pos = $featureHash{$s}->[0]->start;
      my $max_pos = $featureHash{$s}->[0]->start;
      my $strand =  $featureHash{$s}->[0]->strand;
      my $can_merge = 1 if $s;
      
      foreach my $f (@{$featureHash{$s}}) {
        $can_merge = 0 if ($f->strand != $strand ||
                           abs($f->start - $min_pos) > $range/100 ||
                           abs($f->start - $max_pos) > $range/100 );
        $min_pos = ($f->start < $min_pos)?$f->start:$min_pos;
        $max_pos = ($f->start > $max_pos)?$f->start:$max_pos;
      }
      if ($can_merge) {
        my $f = $featureHash{$s}->[0];
        $f->display_name($s);
        if ($f->strand > 0) {
          $plus_inserts->add_feature($f);
        } else {
          $minus_inserts->add_feature($f);
        }
      } else {
        foreach my $f (@{$featureHash{$s}}) {
          if ($f->strand > 0) {
            $plus_inserts->add_feature($f);
          } else {
            $minus_inserts->add_feature($f);
          }
        }
      }
    }
  }
  
  # get the genes
  #my $chado_session = new Session({-log_level=>0,
  #                -dbistr=>'dbi:Pg:dbname=chacrm_4_2;host=mastermind.lbl.gov'});
  #my $chado = new ChadoGeneModelSet($chado_session,
  #                $scaffold,$start_pos,$end_pos)->select;
  #$chado_session->exit;

  my $chado = $session->GeneModelSet($scaffold.'.rel'.$rel,
                                  $start_pos,$end_pos)->select;

  # repackage these to group the exons into transcripts.
  my %models;
  foreach my $exon ($chado->as_list) {
    unless ( exists($models{$exon->transcript_name}) ) {
      $models{$exon->transcript_name} = {start=>$exon->exon_start,
                                           end=>$exon->exon_end,
                                        strand=>$exon->exon_strand,
                     exons=>[[$exon->exon_start,$exon->exon_end]] };
    } else {
      $models{$exon->transcript_name}->{start} = $exon->exon_start
               if $exon->exon_start < $models{$exon->transcript_name}->{start};
      $models{$exon->transcript_name}->{end} = $exon->exon_end
               if $exon->exon_end > $models{$exon->transcript_name}->{end};
      push @{$models{$exon->transcript_name}->{exons}},
                              [$exon->exon_start,$exon->exon_end];
    }
  }
      

  foreach my $g ( keys %models ) {
    my $gene = new Bio::SeqFeature::Gene::Transcript(
                                       -start=>$models{$g}->{start},
                                       -end=>$models{$g}->{end});
    foreach my $e ( @{$models{$g}->{exons}} ) {
      $gene->add_sub_SeqFeature(
           new Bio::SeqFeature::Gene::Exon(-start=>$e->[0],
                                           -end=>$e->[1]),'EXPAND');
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

  $session->exit;

  return $panel;

}

sub colorCallback {
  my $f = $_[0];
  return 'green' unless $f;
  my @s = $f->each_tag_value('status');
  my %color=(new=>'red','permanent'=>'cyan',other=>'green');
  return 'green' unless exists $color{$s[0]};
  return $color{$s[0]};
}

1;
