=head1 Name

   GeneModelSet.pm Extract the gene models by looking at the copied
   Chado tables

=head1 Usage

  use GeneModelSet
  my $models = new GeneModelSet($session,{-key=>value,...)

  The session handle is required. If a key/value pairs
  available for selection are:

  scaffold  the arm
  start     the lower limit
  end       the upper limit
  gene
  transcript
  exon

  $session will need to have a db handle for a second connection
  NOTE: this is harcoded for feature_relationship and type_id's.
=cut

package GeneModelSet;

use base 'SQLObjectSet';
use flybase::Cvterm ':all';
use Pelement;

=head1 new

  The constructor. We can to pass a scaffold, start and end coordinates

=cut

sub new
{
  my $class = shift;
  my $session = shift || die "Session argument required.";
  my $scaffold = shift || '';
  my $start = shift || '';
  my $end = shift || '';

  my $sql = qq(select a.feature_id as scaffold_id,
                      a.name as scaffold_name,
                      a.uniquename as scaffold_uniquename,
                      a.type_id as scaffold_type_id,
                      g.feature_id as gene_id,
                      g.name as gene_name,
                      g.uniquename as gene_uniquename,
                      g.type_id as gene_type_id,
                      t.feature_id as transcript_id,
                      t.name as transcript_name,
                      t.uniquename as transcript_uniquename,
                      t.type_id as transcript_type_id,
                      e.feature_id as exon_id,
                      e.name as exon_name,
                      e.uniquename as exon_uniquename,
                      e.type_id as exon_type_id,
                      i.fmin as gene_start,
                      i.fmax as gene_end,
                      i.strand as gene_strand,
                      j.fmin as transcript_start,
                      j.fmax as transcript_end,
                      j.strand as transcript_strand,
                      l.fmin as exon_start,
                      l.fmax as exon_end,
                      l.strand as exon_strand
                      from
                      $FLYBASE_VERSION.feature a, $FLYBASE_VERSION.feature g, $FLYBASE_VERSION.feature t, $FLYBASE_VERSION.feature e,
                      $FLYBASE_VERSION.feature_relationship gt, $FLYBASE_VERSION.feature_relationship te,
                      $FLYBASE_VERSION.featureloc i, $FLYBASE_VERSION.featureloc j, $FLYBASE_VERSION.featureloc l
               where e.type_id=$GeneModelSet::exon_type_id and
                     t.type_id in $GeneModelSet::transcript_type_id and
                     g.type_id=$GeneModelSet::gene_type_id and
                     i.feature_id=g.feature_id and
                     j.feature_id=t.feature_id and
                     l.feature_id=e.feature_id and
                     a.feature_id=l.srcfeature_id and
                     a.feature_id=j.srcfeature_id and
                     a.feature_id=i.srcfeature_id and
                     te.subject_id=e.feature_id and
                     te.object_id=t.feature_id and
                     te.type_id=$GeneModelSet::part_of and
                     gt.subject_id=t.feature_id and
                     gt.object_id=g.feature_id and
                     gt.type_id=$GeneModelSet::part_of and );

  $sql .= qq(a.uniquename='$scaffold' and ) if $scaffold;
  $sql .= qq(i.fmax >= $start and ) if $start;
  $sql .= qq(i.fmin <= $end and ) if $end;

  $sql =~ s/ and $//s;
  ##$sql .= ' limit 10000';

  return bless new SQLObjectSet($session,$sql), $class;
}

1;
