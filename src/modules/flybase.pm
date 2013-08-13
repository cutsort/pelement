package flybase;
use Session;
use Pelement;
use strict;
use warnings;

sub AUTOLOAD {
  my $self = shift;
  my $package = __PACKAGE__;
  our $AUTOLOAD;
  my $flybase_schema = lc($FLYBASE_SCHEMA);
  die "$self is not an object." unless ref($self);
  ($Session::AUTOLOAD = $AUTOLOAD) =~ s/^${package}::/${flybase_schema}::/;
  return $self->Session::AUTOLOAD(@_);
}

1;
