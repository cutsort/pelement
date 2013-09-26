=head1 NAME

   EditTrace::GDInterface

   a drawable interface to the TraceData::plot routine.

=cut

package EditTrace::GDInterface;

use GD;

=head1 new

  The constructor

=cut

@ISA = qw(GD::Image);

sub new
{
  my $class = shift;


  my $self = {};

  $self->{width} = $_[0];
  $self->{height} = $_[1];
  $self->{image} = new GD::Image(@_);
  $self->{last} = [0,0];
  $self->{color} = $self->{image}->colorAllocate(0,0,0);
  $self->{font} = gdMediumBoldFont;
  $self->{ytext} = 0;

  return  bless $self,$class;
}

=head1 moveto, lineto

  These are the two routines required by TraceData::plot.

=cut
sub moveto
{
  my $self = shift;
  $self->{last} = [(shift || 0 ),$self->{height} - (shift || 0)];
  
}

sub lineto
{
  my $self = shift;
  my ($x,$y) = @_;
  $y = $self->{height}-$y;
  $self->{image}->line($self->{last}->[0],$self->{last}->[1],$x,$y,$self->{color});
  $self->{last} = [$x,$y];

}

sub endline
{
  my $self = shift;
}

sub printbase
{
  my $self = shift;

  my $pos = shift;
  my $char = shift;

  my $ypos = $self->{ytext} || 0;

  $self->{image}->string(gdMediumBoldFont,$pos-3,$self->{height}-$ypos,$char,$self->{color});
}

sub DESTROY { }
1;
