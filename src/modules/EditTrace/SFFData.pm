=head1 NAME 

EditTrace::SFFData

=head1 DESCRIPTION

Reads in an SFF file

Visit the following URL for the SFF specification:
http://www.ncbi.nlm.nih.gov/Traces/trace.cgi?cmd=show&f=formats&m=doc&s=formats#sff 

=cut

package EditTrace::SFFData;
use strict;
use warnings;
no warnings 'once';
no warnings 'redefine';

use FileHandle;
use List::Util qw(min max);
#use bignum; # for the 64-bit index_offset field
use EditTrace::TraceData;
our @ISA = qw(EditTrace::TraceData);

BEGIN {
    # the magic number identifying a SFF file
    our $SFF_MAGIC = ".sff";
}

sub new {
  my $class = shift;
  my $file = shift;
  my $self = EditTrace::TraceData->new;

  my $fh = FileHandle->new($file, 'r') 
    or $self->error("Could not read file $file");
  $fh->binmode; 
  $self->{file} = $file;
  $self->{fh} = $fh;

  $self->{Header}->{type} = "sff";
  $self->{number} = 0;

  # read the file header
  &readHeader($self,$fh);
  &validateHeader($self);
  $self->{read_start_pos} = $fh->tell;

  return bless $self, $class;
}

sub read {
  my $self = shift;
  my $name = shift;
  my $number = shift;
  my $skip_build_interface = shift;

  $self->{number}++;
  my $fh = $self->{fh};
  return 0 if $fh->eof;

  # skip over the index section
  if ($fh->tell == $self->{index_offset}) {
    $fh->seek($self->{index_length}, 1);
  }

  # seek to record name or number if requested
  if (defined $name) {
    return $self->seekToName($name) 
  }
  elsif (defined $number) {
    return $self->seekToNumber($number);
  }

  # Read Header Section
  my $buffer = '';
  $fh->read($buffer, 16);
  (
    $self->{read_header_length},
    $self->{name_length},
    $self->{number_of_bases},
    $self->{clip_qual_left},
    $self->{clip_qual_right},
    $self->{clip_adapter_left},
    $self->{clip_adapter_right},
  ) = unpack 'n n N n n n n', $buffer;

  $self->{name} = '';
  $fh->read($self->{name}, $self->{name_length});

  $buffer = '';
  $fh->read($buffer, 8-($fh->tell % 8)) if $fh->tell % 8;
  $self->{eight_byte_padding2} = $buffer;

  # Read Data Section
  $buffer = '';
  $fh->read($buffer, 
    $self->{number_of_flows_per_read}*$self->{flowgram_bytes_per_flow}
  );
  $self->{flowgram_values} = [
    map {($_*1.0)/100.0} unpack 'n'.$self->{number_of_flows_per_read}, $buffer
  ];

  $buffer = '';
  $fh->read($buffer, $self->{number_of_bases});
  $self->{flow_index_per_base} = [unpack 'C'.$self->{number_of_bases}, $buffer];

  $buffer = '';
  $fh->read($buffer, $self->{number_of_bases});
  $self->{bases} = $buffer;

  $buffer = '';
  $fh->read($buffer, $self->{number_of_bases});
  $self->{quality_scores} = [unpack 'C'.$self->{number_of_bases}, $buffer];

  $buffer = '';
  $fh->read($buffer, 8-($fh->tell % 8)) if $fh->tell % 8;
  $self->{eight_byte_padding3} = $buffer;

  $self->validateRead;

  # add some calculated values
  if (!$skip_build_interface) {
    $self->build_interface;
  }

  return 1;
}

sub readHeader {
  my $self = shift;
  my $fh = shift;

  # Common Header Section
  my $buffer = '';
  $fh->read($buffer, 31);
  (
    $self->{magic_number},
    $self->{version},
    $self->{index_offset},
    $self->{index_length},
    $self->{number_of_reads},
    $self->{header_length},
    $self->{key_length},
    $self->{number_of_flows_per_read},
    $self->{flowgram_format_code},
  ) = unpack 'a4 a4 a8 N N n n n C', $buffer;

  $self->{flowgram_bytes_per_flow} = 2 
    if $self->{flowgram_format_code} == 1;

  # read 64-bit big-endian value
  $self->{index_offset} = read_big_endian(split //, $self->{index_offset});

  $buffer = '';
  $fh->read($buffer, $self->{number_of_flows_per_read});
  $self->{flow_chars} = $buffer;
    
  $buffer = '';
  $fh->read($buffer, $self->{key_length});
  $self->{key_sequence} = $buffer;

  $buffer = '';
  $fh->read($buffer, 8-($fh->tell % 8)) if $fh->tell % 8;
  $self->{eight_byte_padding} = $buffer;
}

sub name {
  my $self = shift;
  return $self->{name};
}

sub validateHeader {
  my $self = shift;
  $self->error("Invalid file format: \$self->{magic_number}") 
    if $self->{magic_number} ne '.sff';
  $self->error("Invalid SFF version: \$self->{version}") 
    if $self->{version} ne "\0\0\0\1";
  $self->error("Bad header length") 
    if $self->{header_length} != 31 + $self->{number_of_flows_per_read}
        +$self->{key_length} + length($self->{eight_byte_padding});

  $self->error("Unknown flowgram format code: \$self->{flowgram_format_code}") 
    if $self->{flowgram_format_code} != 1;
  $self->error("Bad flow characters") 
    if $self->{flow_chars} !~ /^[ACGT]*$/;
  $self->error("File has bad data") if $self->{eight_byte_padding} !~ /^\0*$/;
  #warn "Indexes not yet supported" 
    #if $self->{index_length} != 0 || $self->{index_offset} != 0;
}

sub build_interface {
  my $self = shift;

  # Header
  $self->{Header} = {};
  $self->{Header}{type} = "sff";
  $self->{Header}{samples} = $self->{number_of_flows_per_read};

  # Bases
  my $total = 0;
  $self->{Bases} = [];
  my @bases = split //, $self->{bases};
  for my $i (0..$#bases) {
    $self->{Bases}[$i] = {};
    $self->{Bases}[$i]{base} = $bases[$i];
    $self->{Bases}[$i]{peak} = $self->{flow_index_per_base}[$i]+$total-1; 
    for my $base (split //, $self->{key_sequence}) {
      $self->{Bases}[$i]{$base.'p'} = 
        ($base eq $bases[$i])? $self->{quality_scores}[$i]: 0;
    }
    $total += $self->{flow_index_per_base}[$i];
  }

  # Data
  my @flow_chars = split //, $self->{flow_chars};
  for my $i (0..$#flow_chars) {
    my $flow = $flow_chars[$i];
    for my $base (split //, $self->{key_sequence}) {
      $self->{Data}{$base}[$i] = 
        ($base eq $flow)? $self->{flowgram_values}[$i]: 0;
    }
  }

  # some calculated values
  $self->{first_base_of_insert} = first_base_of_insert(
    $self->{clip_qual_left}, $self->{clip_adapter_left}
  );
  $self->{last_base_of_insert} = last_base_of_insert(
    $self->{clip_qual_right}, $self->{clip_adapter_right}, 
    $self->{number_of_bases},
  );
  return;
}

sub validateRead {
  my $self = shift;
  $self->error("File has bad data") if $self->{eight_byte_padding2} !~ /^\0*$/;
  $self->error("File has bad data") if $self->{eight_byte_padding3} !~ /^\0*$/;
}

sub seekToNumber {
  my $self = shift;
  my $number = shift;
  my $fh = $self->{fh};

  # start from the beginning of the file
  $fh->seek($self->{read_start_pos}, 0);
  $self->{number} = 0;

  while (1) {
    $self->read(undef, undef, 1);
    last if $self->{number} == $number || $fh->eof;
  }
  $self->build_interface;
  return $self->{number} eq $number;
}

sub seekToName {
  my $self = shift;
  my $name = shift;
  my $fh = $self->{fh};

  # start from the beginning of the file
  $fh->seek($self->{read_start_pos}, 0);
  $self->{number} = 0;

  while (1) {
    $self->read(undef, undef, 1);
    last if $self->{name} eq $name || $fh->eof;
  }
  $self->build_interface;
  return $self->{name} eq $name;
}

=head1 readIndex

Seeks to and reads the index section of the SFF file

=cut

sub readIndex {
  my $self = shift;
  $self->error("SFFData::readIndex not yet fully implemented");
  my $fh = shift;
  my $index_offset = shift;
  my $index_length = shift;
  my $index = {};

  my $save_pos = $fh->tell;
  $fh->seek($index_offset, 0);

  my $buffer = '';
  $fh->read($buffer, 8);
  (
    $index->{magic_number},
    $index->{version},
  ) = unpack 'N a4', $buffer;

  $buffer = '';
  $fh->read($buffer, 8-($fh->tell % 8)) if $fh->tell % 8;
  $index->{eight_byte_padding2} = $buffer;

  $fh->seek($save_pos, 0);
  return $index;
}
sub writeFile {
  $_[0]->error("EditTrace::SFFData::writeFile has not been implemented yet");
}
sub check {
  $_[0]->error("EditTrace::SFFData::check has not been implemented yet");
}

=head1 read_big_endian

Reads a list of big-endian bytes and converts
it to a number

=cut

sub read_big_endian {
  my @bytes = @_;
  my $value = 0;
  $value += ord($bytes[$_])*(256**($#bytes-$_)) for 0..$#bytes;
  return $value;
}

=head1 first_base_of_insert

=cut

sub first_base_of_insert {
  my $clip_qual_left = shift;
  my $clip_adapter_left = shift;
  return max(1, max($clip_qual_left, $clip_adapter_left));
}

=head1 last_base_of_insert

=cut

sub last_base_of_insert {
  my $clip_qual_right = shift;
  my $clip_adapter_right = shift;
  my $number_of_bases = shift;
  return min(
    ($clip_qual_right==0 ? $number_of_bases : $clip_qual_right), 
    ($clip_adapter_right==0 ? $number_of_bases : $clip_adapter_right )
  );
}

