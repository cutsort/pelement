=head1 NAME

  PCommon. Pervasive routines of no specific use.

=cut

package PCommon;

=head1 parseArg

  The common interface to parsing optional arguments to
  processing routines. All optional arguments are specified as
  a hash reference with keys either '-key' or 'key'.
  This routine looks for 1 key are returns the first found
  value


=cut

package PCommon;

use Exporter ();
@ISA = qw(Exporter);
@EXPORT = qw(parseArgs shell time_value is_true);

use Sys::Hostname ();

use Pelement;
use strict;

sub parseArgs
{
  my $argRef = shift;
  my $name = shift;

  # '-key' has precedence over 'key'
  return $argRef->{"-$name"} if exists $argRef->{"-$name"};
  return $argRef->{$name} if exists $argRef->{$name};
  return;
}

sub shell
{
  my $cmd = shift;
  return `$cmd`;
}

=head1

  is_true Are we certain how the db returns true values?

=cut
sub is_true
{
  my $val = shift;
  return $val eq 'T' || $val eq 't' || $val eq '1';
}

sub hostname
{
  return Sys::Hostname::hostname();
}

=head2 time_value

  returns a consistently formated date/time string of either a
  specified seconds-since-the-epoch, or now. The format is
  something that should be understandable to the db.

  Changes need to be coordinated with sort_time_value
  
=cut

sub time_value
{
  my @localtimeVal = localtime(shift || time);
  $localtimeVal[5] += 1900;
  $localtimeVal[4]++;

  # zero pad month,day,hour,min,sec
  foreach my $tic (@localtimeVal[0..4]) {
     $tic = '0'.$tic if $tic =~ /^\d$/;
  }

  return join("-",reverse(@localtimeVal[3..5]))." ".
                           join(":",reverse(@localtimeVal[0..2]));
}

=head2 sort_time_value

  A convenience routine to sort the previously formatted times.
  This sorts on the globals $a and $b;

=cut

sub sort_time_value
{
  return sort 
  {
     # this splits the time stamp into a set of numbers:
     # year month day hour minute second. then we can sort on
     # each numerically.
     my @aParts = split(/[ :-]/,$a);
     my @bParts = split(/[ :-]/,$b);

     descend(\@aParts,\@bParts,0);

     sub descend {
        my ($aRef,$bRef,$i) = @_;
        return (($aRef->[$i]) <=> ($bRef->[$i])) ||
                           ($i==5?0:descend($aRef,$bRef,$i+1));
     }
 } @_;

}
1;
