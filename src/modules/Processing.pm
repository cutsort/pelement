=head1 NAME Processing.pm

   various (static) routines for dealing with processing step

=cut

package Processing;

=head1 batch_id, digestion_id, ligation_id, ipcr_id

  Determine the batch, digestion, ligation or ipcr step.

=cut
sub batch_id
{
   my $id = shift;
   my @f = split_steps($id);
   return $f[0];
}
sub digestion_id
{
   my $id = shift;
   my @f = split_steps($id);
   return join(".",@f[0..1]);
}
sub ligation_id
{
   my $id = shift;
   my @f = split_steps($id);
   return join(".",@f[0..2]);
}
sub ipcr_id
{
   my $id = shift;
   my @f = split_steps($id);
   return join(".",@f[0..3]);
}

sub split_steps
{
  return split(/\./,shift);
}

1;
