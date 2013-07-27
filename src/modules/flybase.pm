package flybase;
use Session;
use Pelement;
use strict;
use warnings;

sub AUTOLOAD {
  my $self = shift;
  my $package = __PACKAGE__;
  our $AUTOLOAD;
  my $flybase_version = lc($FLYBASE_VERSION);
  die "$self is not an object." unless ref($self);
  ($Session::AUTOLOAD = $AUTOLOAD) =~ s/^${package}::/${flybase_version}::/;
  return $self->Session::AUTOLOAD(@_);
}

1;
