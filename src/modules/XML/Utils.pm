package XML::Utils;

use Exporter();
@ISA = qw(Exporter);
@EXPORT = qw(check_for_null_attribute check_for_null_element check_attribute_option);

sub check_for_null_attribute
{
   my ($obj,$key) = @_;
   return ref($obj)." requires a value for the attribute $key." unless $obj->{$key};
   return;
}
sub check_for_null_element
{
   my ($obj,$key) = @_;
   return ref($obj)." requires an element $key." unless $obj->{$key};
   return ref($obj)." requires an element in the array for $key."
               if ref($obj->{$key}) eq "ARRAY" && !scalar(@{$obj->{$key}});
   return;
}

sub check_attribute_option
{
   my ($obj,$key,$valRef) = @_;
   my $val = $obj->{$key};
   return ref($obj)." value for $key is not valid."
                                 unless grep(/^$val$/,@$valRef);
   return;
}

1;
