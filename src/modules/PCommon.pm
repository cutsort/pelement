=head1 NAME

  PCommon. Pervasive routines of no specific use.

=cut

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
@EXPORT = qw(parseArgs shell time_value is_true date_cmp seq_extract);

use Sys::Hostname ();
use FileHandle;

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

=head1

  date_cmp Needed when sorting dates.

  lexigraphic comparisons are easy.

=cut
sub date_cmp
{
   return $_[0] cmp $_[1];
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

=head1 seq_extract

Extract the substring of first sequence from a fasta file where the header
matches $pat.

=cut

sub seq_extract {
  my ($file, $pat, $start, $stop) = @_;
  local $/ = '>';
  my $fh = FileHandle->new($file,'r')
    or die "Could not read file $file: $!";
  $fh->getline;
  while (my $fasta = $fh->getline) {
    chomp $fasta; 
    $fasta=~s/^([^\n]*)\n//;
    my $header = $1;
    if (!defined($pat) || (ref($pat) eq 'Regexp'? $header=~/$pat/ : ref($pat) eq 'CODE'? $pat->($header) : $header=~/\Q$pat\E/)) {
      $fasta=~s/\s+//g;
      my $start = !defined($start) || $start < 0 ? 0 : $start;
      my $stop = !defined($stop) || $stop < 0 ? length($fasta) : $stop;
      my $length = $stop-$start < 0? 0 : $stop-$start;
      return substr($fasta, $start, $length);
    }
  }
  undef;
}

1;

