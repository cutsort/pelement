package XML::Base;

=head1 Name

   XML::Base.pm A base module for generating XML for flybase submissions


=head1 Usage
   
   This module is not intended to be used directly but should be subclassed.

=cut

use Exporter();
@ISA = qw(Exporter);
@EXPORT = qw(new add attribute validate to_xml);

use XML::Utils;

sub new
{
   my $class = shift;
   my $self = shift || {};

   return bless $self,$class;
}

=head1 attribute sets or gets the attribute

  If called with a pair (key,value) it will set key to
  value. If called with a single key, then the value is
  returned.

=cut
  
sub attribute
{
   my $self = shift;

   while (scalar(@_)>1) {
      my $key = shift;
      my $value = shift;
      $self->{$key} = $value;
   }

   if (@_) {
      return $self->{shift(@_)};
   } else {
      return $self;
   }
}

sub add
{
   my $self = shift;
   my $obj = shift;

   my $whatIam = ref($self);
   my $whatItIs = ref($obj);
   
   if ( grep(/$whatItIs$/,@{$whatIam."::ElementList"}) ) {
      $self->{$whatItIs} = $obj;
   } elsif ( grep(/$whatItIs$/,@{$whatIam."::ElementListList"}) ) {
      $self->{$whatItIs} = [] unless exists $self->{$whatItIs};
      push @{$self->{$whatItIs}},$obj;
   } else {
      die "Cannot add $whatItIs to $whatIam.";
   }
}
sub validate
{
   my $self = shift;
   my $msg;
   map { return $msg if ($msg = check_for_null_attribute($self,$_)) }
                                   @{ref($self)."::AttributeRequiredList"};
   map { return $msg if ($msg = check_for_attribute_option($self,$_),${ref($self)."::OptionHash"}{$_}) }
                                   keys %{ref($self)."::AttributeOptionHash"};
   map { return $msg if ($msg = check_for_null_element($self,$_)) }
                                   @{ref($self)."::ElementRequiredList"};
   map { return $msg if ($_ and $msg = $_->validate) } @{ref($self)."::ElementList"};
   map { map{ return $msg if ($_ and $msg = $_->validate) } @$_ } @{ref($self)."::ElementListList"};
   return;
}

sub to_xml
{

   my $self = shift;
   my $writer = shift;

   (my $name = ref($self)) =~ s/XML:://;

   my @atts = ();
   foreach $att (@{ref($self)."::AttributeRequiredList"},@{ref($self)."::AttributeOptionalList"} ) {
      push @atts,$att,$self->{$att} if exists($self->{$att}) && $self->{$att} ne '';
   }

   if( @{ref($self)."::ElementList"} || @{ref($self)."::ElementListList"} ) {
      $writer->open($name,@atts);

      foreach $element (@{ref($self)."::ElementList"}) {
         $self->{$element}->to_xml($writer) if exists($self->{$element});
      }
      foreach $elementList (@{ref($self)."::ElementListList"}) {
         next unless exists($self->{$elementList});
         foreach $element (@{$self->{$elementList}}) {
            $element->to_xml($writer);
         }
      }
 
      $writer->close($name);
   } else {
      $writer->tag($name,@atts);
   }

}

1;
