package Gel;

=head1 Name

   Gel.pm A module for the encapsulation of gel processing information

=head1 Usage

  use Gel;
  $gel = new Gel($session,{-key1=>val1,-key2=>val2...});

  The session handle is required. If a key/value pair
  is given to uniquely identify a row from the database,
  that information can be selected.

=cut

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use DbObject;

=head1 default_dir

  Returns the name of a default directory of a gel within
  our processing rules. This is either callable as an object
  method: $gel->default_dir or as a static method: Gel::default_dir($gel_name);

  The default directory is determined by the class and number of the gel;
  PT0456 is class PT and number 456. this will be in a group PT400_499
  and named PT0456.1

=cut
sub default_dir
{
    my $self = shift;
    my $name = ref($self)?$self->name:$self;
    my $version = shift || 1;

    if ($name =~ /^([A-Z]*)(\d+)/ ) {
       my $class = $1;
       my $gel_number = $2;
       my $gel_lo = 100*int($gel_number/100);
       my $gel_hi = $gel_lo + 99;
       return $PELEMENT_TRACE.$class.$gel_lo."_".$gel_hi."/".$name.".".$version.'/';
    } else {
       return;
    }
}

1;
