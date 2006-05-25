=head1 Name

   ChadoGeneModelSet.pm Extract the gene models by chatting with chado.

=head1 Usage

  use ChadoGeneModelSet
  my $models = new ChadoModelSet($session,{-key=>value,...)

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

package ChadoGeneModelSet;

use SQLObjectSet;

BEGIN {
  # these change between shapshots only; it may speed up queries to code these.
  $ChadoGeneModelSet::part_of = 59639;
  $ChadoGeneModelSet::exon_type_id = 59812;
  $ChadoGeneModelSet::transcript_type_id = 59899;
  $ChadoGeneModelSet::gene_type_id = 60369;
}

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
                      l.fmin as exon_start,
                      l.fmax as exon_end,
                      l.strand as exon_strand,
                      j.fmin as gene_start,
                      j.fmax as gene_end,
                      j.strand as gene_strand,
                      k.fmin as transcript_start,
                      k.fmax as transcript_end,
                      k.strand as transcript_strand
                      from
                      feature a, feature g, feature t, feature e,
                      feature_relationship gt, feature_relationship te,
                      featureloc l, featureloc j, featureloc k
               where e.type_id=$ChadoGeneModelSet::exon_type_id and
                     t.type_id=$ChadoGeneModelSet::transcript_type_id and
                     g.type_id=$ChadoGeneModelSet::gene_type_id and
                     l.feature_id=e.feature_id and
                     j.feature_id=g.feature_id and
                     k.feature_id=t.feature_id and
                     a.feature_id=l.srcfeature_id and
                     te.subject_id=e.feature_id and
                     te.object_id=t.feature_id and
                     te.type_id=$ChadoGeneModelSet::part_of and
                     gt.subject_id=t.feature_id and
                     gt.object_id=g.feature_id and
                     gt.type_id=$ChadoGeneModelSet::part_of and
                     not a.is_obsolete and
                     not g.is_obsolete and
                     not t.is_obsolete and
                     not e.is_obsolete and );

  $sql .= qq(a.name='$scaffold' and ) if $scaffold;
  $sql .= qq(l.fmax >= $start and ) if $start;
  $sql .= qq(l.fmin <= $end and ) if $end;

  $sql =~ s/ and $//s;
  ##$sql .= ' limit 10000';

  return bless new SQLObjectSet($session,$sql), $class;
}

1;
