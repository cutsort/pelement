package GeneralUtils::Structures;

use Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(rearrange remove_duplicates merge_hashes get_method_ref
	       get_param);

use strict;
use Carp qw(confess carp cluck);

=head2 rearrange()

 Usage    : n/a
 Function : Rearranges named parameters to requested order.
 Returns  : @params - an array of parameters in the requested order.
 Argument : $order : a reference to an array which describes the desired
                     order of the named parameters.
            @param : an array of parameters, either as a list (in
                     which case the function simply returns the list),
                     or as an associative array (in which case the
                     function sorts the values according to @{$order}
                     and returns that new array.

 Exceptions : carps if a non-recognised parameter is sent

=cut

sub rearrange {
  # This function was taken from CGI.pm, written by Dr. Lincoln
  # Stein, and adapted for use in Bio::Seq by Richard Resnick.
  # ...then Chris Mungall came along and adapted it for BDGP
  my($order,@param) = @_;

  # If there are no parameters, we simply wish to return
  # an undef array which is the size of the @{$order} array.
  return (undef) x $#{$order} unless @param;

  # If we've got parameters, we need to check to see whether
  # they are named or simply listed. If they are listed, we
  # can just return them.
  return @param unless (defined($param[0]) && $param[0]=~/^-/);

  # Now we've got to do some work on the named parameters.
  # The next few lines strip out the '-' characters which
  # preceed the keys, and capitalizes them.
  my $i;
  for ($i=0;$i<@param;$i+=2) {
      if (!defined($param[$i])) {
	  cluck("Hmmm in $i ".join(";", @param)." == ".join(";",@$order)."\n");
      }
      else {
	  $param[$i]=~s/^\-//;
	  $param[$i]=~tr/a-z/A-Z/;
      }
  }
  
  # Now we'll convert the @params variable into an associative array.
  my(%param) = @param;

  my(@return_array);
  
  # What we intend to do is loop through the @{$order} variable,
  # and for each value, we use that as a key into our associative
  # array, pushing the value at that key onto our return array.
  my($key);

  foreach $key (@{$order}) {
      $key=~tr/a-z/A-Z/;
      my($value) = $param{$key};
      delete $param{$key};
      push(@return_array,$value);
  }
  
  # catch user misspellings resulting in unrecognized names
  my(@restkeys) = keys %param;
  if (scalar(@restkeys) > 0) {
       carp("@restkeys not processed in rearrange(), did you use a
       non-recognized parameter name ? ");
  }
  return @return_array;
}




=head2 get_param()

Usage    : get_param('name',(-att1=>'ben',-name=>'the_name'))
Function : Fetches a  named parameter.
Returns  : The value of the requested parameter.
Argument : $name : The name of the the parameter desired
           @param : an array of parameters, as an associative array 
Exceptions : carps if a non-recognised parameter is sent

Based on rearrange(), which is originally from CGI.pm by Lincoln
Stein and BioPerl by Richard Resnick.  See rearrange() for details.

=cut

sub get_param
  {

  # This function was taken from CGI.pm, written by Dr. Lincoln
  # Stein, and adapted for use in Bio::Seq by Richard Resnick.
  # ...then Chris Mungall came along and adapted it for BDGP
    # ... and ben berman added his 2 cents.

  my($name,@param) = @_;

  # If there are no parameters, we simply wish to return
  # false.
  return '' unless @param;

  # If we've got parameters, we need to check to see whether
  # they are named or simply listed. If they are listed, we
  # can't return anything.
  return '' unless (defined($param[0]) && $param[0]=~/^-/);

  # Now we've got to do some work on the named parameters.
  # The next few lines strip out the '-' characters which
  # preceed the keys, and capitalizes them.
  my $i;
  for ($i=0;$i<@param;$i+=2) {
        $param[$i]=~s/^\-//;
        $param[$i] = uc($param[$i]);
  }
  
  # Now we'll convert the @params variable into an associative array.
  my(%param) = @param;

  # We capitalize the key, and use it as a key into our
  # associative array
  my $key = uc($name);
  my $val = $param{$key};

  return $val;
}






























=head2 remove_duplicates

remove duplicate items from an array

 usage: remove_duplicates(\@arr)

affects the array passed in, and returns the modified array

=cut

sub remove_duplicates {
    
    my $arr_r = shift;
    my @arr = @{$arr_r};
    my %h = ();
    my $el;
    foreach $el (@arr) {
	$h{$el} = 1;
    }
    my @new_arr = ();
    foreach $el (keys %h) {
	push (@new_arr, $el);
    }
    @{$arr_r} = @new_arr;
    @new_arr;
}

=head1 merge_hashes

joins two hashes together

 usage: merge_hashes(\%h1, \%h2);

%h1 will now contain the key/val pairs of %h2 as well. if there are
key conflicts, %h2 values will take precedence.

=cut

sub merge_hashes {
    my ($h1, $h2) = @_;
    map {
	$h1->{$_} = $h2->{$_};
    } keys %{$h2};
    return $h1;
}

=head1 get_method_ref

 returns a pointer to a particular objects method
 e.g.   my $length_f = get_method_ref($seq, 'length');
        $len = &$length_f();

=cut

sub get_method_ref {
    my $self = shift || confess;
    my $method = shift;
    my $sub = sub {return $self->$method(@_)};
    return $sub;
}
  
1;
