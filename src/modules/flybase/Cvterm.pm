=head1 Name

  Package to store all the cvterm values.

=cut

package flybase::Cvterm;
use strict;
use DbObject;

our @ISA = qw(Exporter DbObject);
our @EXPORT_OK = qw(
  $part_of $derives_from $exon_type_id $transcript_type_id 
  $polypeptide_type_id $gene_type_id $te_type_id
  $chromsome_type_ids
);
our %EXPORT_TAGS = (all=>\@EXPORT_OK);

tie((our $part_of), 'flybase::Cvterm::Value', 'partof');
tie((our $derives_from), 'flybase::Cvterm::Value', 'producedby');
tie((our $exon_type_id), 'flybase::Cvterm::Value', 'exon');
tie((our $transcript_type_id), 'flybase::Cvterm::Value', qw(mRNA ncRNA rRNA miRNA snoRNA snRNA tRNA));
tie((our $polypeptide_type_id), 'flybase::Cvterm::Value', 'protein');
tie((our $gene_type_id), 'flybase::Cvterm::Value', 'gene');
tie((our $te_type_id), 'flybase::Cvterm::Value', 'transposable_element');
tie((our $chromosome_type_ids), 'flybase::Cvterm::Value', qw(chromosome chromosome_arm));

package flybase::Cvterm::Value;
use base 'Tie::Scalar';

sub TIESCALAR {
  my ($class,@terms) = @_;
  my $self={terms=>\@terms};
  return bless $self, $class;
}

sub FETCH {
  my ($self) = @_;
  if (!exists $self->{value}) {
    my $session = Session::get_instance();
    my @values = $session->flybase::CvtermSet({ 
        -in=>{name=>$self->{terms}},
    })->select->as_list;

    $self->{value} = @values==0? $session->die("No Cvterm records for: $self->{terms}")
      : @values>1 ? '('.(join(',',(map {$session->db->quote($_->cvterm_id)} @values))||'NULL').')' 
      : $session->db->quote($values[0]->cvterm_id);
  }
  return $self->{value};
}

sub STORE {}

1;

