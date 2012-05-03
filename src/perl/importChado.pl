#!/usr/local/bin/perl -I../modules

=head1 NAME

  importChado.pl

=head1 DESCRIPTION 

  The guts of a importing tables from chado. 

  not everything is used so we're trimming it down. Only the transcript models.

=cut

use Pelement;
use Session;

use ChadoGeneModelSet;

use strict;

# what release are we moving from?
my $mig_rel = 5;

my $session = new Session;
# get the genes
my $chado_session = new Session({-log_level=>0,
##             -dbistr=>'dbi:Pg:dbname=chacrm_4_2;host=mastermind.lbl.gov'});
             -dbistr=>'dbi:Pg:dbname=FB2006_01;host=spitz.lbl.gov'});
my $chado = new ChadoGeneModelSet($chado_session)->select;
$session->info("Retrieved ".$chado->count." records.");
$chado_session->exit;

# repackage these to group the exons into transcripts.
my $ctr = 0;
my $ins = 0;
my $ins_ctr = $ChadoGeneModelSet::max_feature_id;

foreach my $model ($chado->as_list) {
  my $arm = $session->Feature({-feature_id => $model->scaffold_id,
                               -name       => $model->scaffold_name,
                               -uniquename => $model->scaffold_uniquename,
                               -type_id    => $model->scaffold_type_id});
  map { $arm->uniquename($_.'.rel'.$mig_rel) if $arm->uniquename eq $_ }
                                                       qw( X 2L 2R 3L 3R 4 );
  ($arm->insert and $ins++) unless $arm->db_exists;
  my $gene = $session->Feature({-feature_id => $model->gene_id,
                                -name       => $model->gene_name,
                                -uniquename => $model->gene_uniquename,
                                -type_id    => $model->gene_type_id});
  ($gene->insert and $ins++) unless $gene->db_exists;
  my $tran = $session->Feature({-feature_id => $model->transcript_id,
                                -name       => $model->transcript_name,
                                -uniquename => $model->transcript_uniquename,
                                -type_id    => $model->transcript_type_id});
  ($tran->insert and $ins++) unless $tran->db_exists;
  my $exon = $session->Feature({-feature_id => $model->exon_id,
                                -name       => $model->exon_name,
                                -uniquename => $model->exon_uniquename,
                                -type_id    => $model->exon_type_id});
  ($exon->insert and $ins++) unless $exon->db_exists;

  my $trel = $session->Feature_Relationship(
                                    {-subject_id => $tran->feature_id,
                                     -object_id  => $gene->feature_id,
                                     -type_id    => $ChadoGeneModelSet::part_of});
  ($trel->insert and $ins++) unless $trel->db_exists;
  my $erel = $session->Feature_Relationship(
                                    {-subject_id => $exon->feature_id,
                                     -object_id  => $tran->feature_id,
                                     -type_id    => $ChadoGeneModelSet::part_of});
  ($erel->insert and $ins++) unless $erel->db_exists;
  my $gene_loc = $session->Featureloc({-feature_id    => $gene->feature_id,
                                       -srcfeature_id => $arm->feature_id,
                                       -fmin          => $model->gene_start,
                                       -fmax          => $model->gene_end,
                                       -strand        => $model->gene_strand});
  ($gene_loc->insert and $ins++) unless $gene_loc->db_exists;
  my $tran_loc = $session->Featureloc(
                                  {-feature_id    => $tran->feature_id,
                                   -srcfeature_id => $arm->feature_id,
                                   -fmin          => $model->transcript_start,
                                   -fmax          => $model->transcript_end,
                                   -strand        => $model->transcript_strand});
  ($tran_loc->insert and $ins++) unless $tran_loc->db_exists;
  my $exon_loc = $session->Featureloc(
                                  {-feature_id    => $exon->feature_id,
                                   -srcfeature_id => $arm->feature_id,
                                   -fmin          => $model->exon_start,
                                   -fmax          => $model->exon_end,
                                   -strand        => $model->exon_strand});
  ($exon_loc->insert and $ins++) unless $exon_loc->db_exists;

  # we're treating start/stop differently than the datasource. We're
  # entering start_codon and stop_codon features and tying these to
  # the transcript
  if ($model->coding_start && $model->coding_end) {
    my $start_codon = $session->Feature({-name       => $model->transcript_name.'_start',
                                         -uniquename => $model->transcript_name.'_start',
                                         -type_id    => $ChadoGeneModelSet::start_codon_type_id});
    unless ($start_codon->db_exists) {
      $start_codon->feature_id(++$ins_ctr);
      $start_codon->insert;
      # these are relative to the transcript.
      my $coord = ($model->transcript_strand > 0)?$model->coding_start:$model->coding_end;
      $session->Featureloc(
              {-feature_id    => $start_codon->feature_id,
               -srcfeature_id => $tran->feature_id,
               -fmin          => $coord - $model->transcript_start,
               -fmax          => $coord - $model->transcript_start,
               -strand        => $model->transcript_strand})->insert;
    }
    my $stop_codon = $session->Feature({-name       => $model->transcript_name.'_stop',
                                        -uniquename => $model->transcript_name.'_stop',
                                        -type_id    => $ChadoGeneModelSet::stop_codon_type_id});
    unless ($stop_codon->db_exists) {
      $stop_codon->feature_id(++$ins_ctr);
      $stop_codon->insert;
      my $coord = ($model->transcript_strand > 0)?$model->coding_end:$model->coding_start;
      $session->Featureloc(
              {-feature_id    => $stop_codon->feature_id,
               -srcfeature_id => $tran->feature_id,
               -fmin          => $coord - $model->transcript_start,
               -fmax          => $coord - $model->transcript_start,
               -strand        => $model->transcript_strand})->insert;
    }
  }
    
  $session->info("Processed $ctr records....") unless ++$ctr%1000;
}

$session->info("Processed $ctr records with $ins insertions.");

# insert the mappings
foreach my $rel qw(3 4 5) {
  next if $rel == $mig_rel;
  foreach my $arm qw(X 2L 2R 3L 3R 4) {
    my $new_arm = $session->Feature({-uniquename=>$arm.'.rel'.$rel});
    next unless $new_arm->db_exists;
    $new_arm->select;
    my $new_id= $new_arm->feature_id;
    my $old_arm = $session->Feature({-uniquename=>$arm.'.rel'.$mig_rel})->select;
    my $old_id = $old_arm->feature_id;
    my $map_fn = 'r'.$mig_rel.'_r'.$rel.'_map';
    my $sql = qq(insert into featureloc
                 (feature_id,srcfeature_id,fmin,fmax,strand)
                 select
                 feature_id,$new_id,$map_fn('$arm',fmin),$map_fn('$arm',fmax),strand
                 from featureloc where
                 srcfeature_id=$old_id and
                 $map_fn('$arm',fmin) is not null and
                 $map_fn('$arm',fmax) is not null);
     $session->debug("SQL: $sql.");
    ## $session->db->do($sql);
  }
}

$session->exit;
