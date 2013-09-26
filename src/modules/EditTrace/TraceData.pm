# this package is the superclass of the classes for specific type of 
# sequencer data files.
#
# this is not intended to be instanced directly but should be used
# via the lower level interfaces.
# the methods here are primarily to define the base constructor and
# means of reading or writing segments of the data structures to or
# from terminals or ascii files.

#
#  History:
#
#
#             23 jan 01 jwc Improved error reporting with the error()
#                           and errorMessage() routines. Removed printing
#                           to STDERR throughout.

# we use the utility methods fromUIint and toUInt a lot; we'll make
# these usable as procedural calls to the subclasses

package EditTrace::TraceData;

use Exporter();
@ISA = qw(Exporter);
@EXPORT = qw(fromUInt toUInt);

BEGIN {
    # parameters needed from the spec for SCF files
    # the magic number identifying a SCF file

    # we need these parameters up here since the SCF format is the
    # default (and so far only) output format for writing files.
    # readFile will always be in a subclass; writeFile might never be.
    $SCF_MAGIC = ".scf";
    $HEADERSIZE = 128;
}

sub new {
    # not too much here. We'll use this to initialize the 4 required
    # data structures required for all file formats and fill it with
    # trivial content

    my $class = shift;

    # the overall model of the data resembles that of an SCF file but
    # need not be limited to it. There should be: 1) some header information
    # of (key,value) pairs which will be stored as a hash, 2) some raw
    # data values on 4 channels (labeled A, C, G and T), 3) a array of
    # data for called bases. there will be an array of values, but what
    # is stored at each point may be implementation dependent. Finally there
    # are comments and private data as two independent string fields.

    my %Header =  (
        type              => "",    # style of file
        samples           => 0,     # the number of samples
        bases             => 0,     # the number of called bases
                );
    
    my %Data = (                    # nothing here
        A => [],                    # this is a hash of arrays
        C => [],
        G => [],
        T => [],
    );

    my $Bases = [];                 # the called bases
                                    # this is a array of hashes
    
    my $Comment = "";               # nothing here, a scalar
    my $Private = "";               # nothing here, a scalar

    my $Messages = [];              # this is a reference to
                                    # internal array of error messages

    # this package returns a reference to this base structure
    my $self = { "Header"=>\%Header,
                 "Data"=>\%Data,
                 "Bases"=>$Bases,
                 "Comment"=>\$Comment,
                 "Private"=>\$Private,
                 "Messages"=>$Messages};

    return bless $self, $class;

}

sub dumpHeader {

    # returns the elements of the Header hash as a formatted ascii list
    # All elements of the generic header are printed.
    my $self = shift;
    my $theHeader = $self->{Header};
    my $retStr = "";

    foreach $key (sort keys %$theHeader) {
        $retStr .= "$key\t$theHeader->{$key}\n";
    }
    return $retStr;
}
sub dumpData {

    # returns the elements of the scan data as a formated ascii list
    # a label: is added in front of every line
    my $self = shift;
    my $theData = $self->{Data};
    my $retStr = "";
    my $i;

    for($i=0;$i<=$#{$theData->{T}};$i++) {
        $retStr .= "$i:\t$theData->{A}[$i]\t$theData->{C}[$i]\t".
              "$theData->{G}[$i]\t$theData->{T}[$i]\n";
    }
    return $retStr;
}
sub dumpBases {
    # returns the elements of the called bases as a formated ascii list
    # a label: is added in front of every line
    my $self = shift;
    my $theBases=$self->{Bases};
    my $i;
    my $retStr = "";

    if( $#{$theBases} ){
        for($i=0;$i<=$#{$theBases};$i++) {
            $retStr .=  "$i:\t$theBases->[$i]{base}\t$theBases->[$i]{Ap}\t".
                        "$theBases->[$i]{Cp}\t$theBases->[$i]{Gp}\t".
                        "$theBases->[$i]{Tp}\t$theBases->[$i]{peak}\n";
        }
    }
    return $retStr;
}

sub dumpComment {
    my $self = shift;
    return ${$self->{Comment}};
}
sub dumpPrivate {
    my $self = shift;
    return ${$self->{Private}};
}
sub readHeader {

    my $self = shift;

    # we're reading the contents of a string which are a tab
    # delimited set of key\tvalue pairs followed by a \n. these values
    # are use to replace values in the data structure or become new entries
    # this may give the appearance of being able to change certain quantities
    # to give inconsistent values (like versions=-10, comment_size=wrong...)
    # everything will be checked for consistency before the file is written.
    my @headLines = split("\n",shift);
    while( @headLines ) {
        ($key,$value) = split("\t",shift @headLines);
        $self->{Header}->{$key} = $value;
    }
}

sub readData {

    my $self = shift;
    my $theData = $self->{Data};

    # clear out the old data
    foreach my $b ("A","C","G","T") {
       $theData->{$b} = [];
    }
    my @dataLines = split("\n",shift);
    while ( @dataLines ) {

        # there is an optional label:\t field in the front of the line
        $dataLines[0] =~ s/^.*:\t*//;

        my @value = split("\t",shift @dataLines);
        push @{$theData->{A}}, $value[0];
        push @{$theData->{C}}, $value[1];
        push @{$theData->{G}}, $value[2];
        push @{$theData->{T}}, $value[3];
    }
}

sub readBases{

    my $self = shift;
    my $theBases = $self->{Bases};

    my @dataLines = split("\n",shift);
    my $i=0;
    while ( @dataLines ) {
        # there is an optional label:\t field in the front of the line
        $dataLines[0] =~ s/^.*:\t*//;

        my @value = split("\t",shift @dataLines);
        $theBases->[$i] = {base=>$value[0],Ap=>$value[1],Cp=>$value[2],
                             Gp=>$value[3],Tp=>$value[4],peak=>$value[5]};
        $i++;
    }
}
sub readComment {
    my $self = shift;
    ${$self->{Comment}} = shift;
}
sub readPrivate {
    my $self = shift;
    ${$self->{Private}} = shift;
}

sub writeFile {

    my $self = shift;
    my $filename = shift;

    my $theHeader = $self->{Header};
    my $theData = $self->{Data};
    my $theBases = $self->{Bases};

    # first, make everything consistent
    $self->check();

    # be nice and make a backup copy. of course this will trash the
    # backup copy
    if (-e $filename) {
        if( ! rename($filename, $filename.".bak") ) {
            $self->error("Cannot make a backup copy.");
        }
    }

    if (!open(FILE,">$filename")) {
        $self->error("Cannot open $filename for writing.");
        return 0;
    }

    my $Buffer = pack("a4" x 14,                            $SCF_MAGIC,
                  fromUInt($theHeader->{samples}         ,4),
                  fromUInt($theHeader->{sample_offset}   ,4),
                  fromUInt($theHeader->{bases}           ,4),
                  fromUInt($theHeader->{bases_left_clip} ,4),
                  fromUInt($theHeader->{bases_right_clip},4),
                  fromUInt($theHeader->{bases_offset}    ,4),
                  fromUInt($theHeader->{comments_size}   ,4),
                  fromUInt($theHeader->{comments_offset} ,4),
                           $theHeader->{version}            ,
                  fromUInt($theHeader->{sample_size}     ,4),
                  fromUInt($theHeader->{code_set}        ,4),
                  fromUInt($theHeader->{private_size}    ,4),
                  fromUInt($theHeader->{private_offset}  ,4));
    # append null bytes
    for(;length($Buffer)<$HEADERSIZE;){
        $Buffer .= chr(0);
    }

    if( !print FILE $Buffer  ) {
        $self->error("Problem writing Header in $filename.");
        close(FILE);
        return 0;
    }

    $Buffer = "";
    $offset = 0;
    for($i=0;$i<$theHeader->{samples};$i++) {
        foreach $base ("A","C","G","T") {
            vec($Buffer,$offset,8*$theHeader->{sample_size}) = $theData->{$base}[$i];
            $offset++;
        }
    }
    if( !print FILE $Buffer  ) {
        $self->error("Problem writing Data in $filename.");
        close(FILE);
        return 0;
    }

    $Buffer = "";
    for($i=0;$i<$theHeader->{bases};$i++) {

        $Buffer .= fromUInt($theBases->[$i]{peak},4);
        $Buffer .= fromUInt($theBases->[$i]{Ap},1);
        $Buffer .= fromUInt($theBases->[$i]{Cp},1);
        $Buffer .= fromUInt($theBases->[$i]{Gp},1);
        $Buffer .= fromUInt($theBases->[$i]{Tp},1);
        $Buffer .=          $theBases->[$i]{base};
        $Buffer .= chr(0).chr(0).chr(0);
    }
    if( !print FILE $Buffer  ) {
        $self->error("Problem writing Bases in $filename.");
        close(FILE);
        return 0;
    }

    if( !print FILE ${$self->{Comment}}  ) {
        $self->error("Problem writing Comments in $filename.");
        close(FILE);
        return 0;
    }

    if( !print FILE ${$self->{Private}} ) {
        $self->error("Problem writing Private in $filename.");
        close(FILE);
        return 0;
    }

    return close(FILE);

}

sub plot {
    # a hook for plotting chromats. We need to pass an object
    # to this method which is capable of moveto(x,y), lineto(x,y), endline, and printbase(x,n)
    # the args for moveto, lineto and the x arg of printbase are coordinates in user space.
    # the n of printbase is the nucleotide to print.

    my $self = shift;
    my $obj = shift;

    # a second optional argument is a hash reference of parameters.
    # possible keys are:
    #  dataRangeX      an array ref of starting and ending indices to go over
    #  dataRangeY      an array ref of clip values for the data. not implemented
    #  xrange, yrange  an array ref of what to scale to
    #  bases           an array ref of channels to plot

    my $argRef = shift || {};

    my $theData = $self->{Data};
    my $theBases = $self->{Bases};

    my ($start,$end) = (exists($argRef->{dataRangeX}))?
                             @{$argRef->{dataRangeX}}:
                             (0,$#{$theData->{T}});
    # these need to be in order
    ($start,$end) = sort { $a <=> $b } ($start,$end);

    # and need to be different
    $end++ if $start == $end;

    my ($xStart,$xEnd) = (exists($argRef->{xrange}))?
                             @{$argRef->{xrange}}:
                             ($start,$end);

    my @bases = (exists($argRef->{bases}))?
                        @{$argRef->{bases}}:
                        qw(A C G T);

    # set fallback max to at least 1 to prevent range problems
    my $dataMax = 1;

    foreach my $base ('A','C','G','T') {
         map { $dataMax = $dataMax>$_?$dataMax:$_ } @{$theData->{$base}};
    }

    my ($yStart,$yEnd) = (exists($argRef->{yrange}))?
                             @{$argRef->{yrange}}:
                             (0,$dataMax);

    # a routine to scale with
    $scaler = sub {
       my ($x,$y) = @_;
       return ( ($x-$start)*($xEnd-$xStart)/($end-$start) + $xStart,
                         $y*($yEnd-$yStart)/$dataMax      + $yStart  );
    };
                     
    foreach my $base (@bases) {
      # sometimes we call this with 'N' to get uncalled peaks.
      next unless grep(/$base/,qw(A C G T));
      $obj->moveto(&$scaler($start,$theData->{$base}[$start]));
      map {  $obj->lineto(&$scaler($_,$theData->{$base}[$_])) } (($start+1)..$end);
    }

    $obj->endline;

    foreach my $base (@bases) {
      foreach my $i (0..$#$theBases) {
         next if $theBases->[$i]->{peak} < $start;
         last if $theBases->[$i]->{peak} > $end;
         next if $theBases->[$i]->{base} ne $base;
         $obj->printbase((&$scaler($theBases->[$i]->{peak},0))[0],$base);
      }
    }
}

sub check {
    # adjust the header values as needed to make sure everything is
    # copasetic. This will add entries into the Header hash so that it
    # can be written as an SCF file.

    # argument is the SCFData structure
    $self = shift;
    my $theHeader = $self->{Header};
    my $theData = $self->{Data};
    my $theComment = $self->{Comment};
    my $thePrivate = $self->{Private};

    # version 2.00 If we want to support version 3, we'll need to
    # update writeFile
    $theHeader->{version} = "2.00";

    # the sample size must be 1 or 2
    if( ! defined($theHeader->{sample_size}) || 
          ($theHeader->{sample_size} != 1 && $theHeader->{sample_size} != 2) ) {
        $theHeader->{sample_size} = 2;
    }

    # we know the data vectors are guaranteed to have the same size
    $theHeader->{samples} = scalar @{$self->{Data}{A}};

    # samples is stored right after the header
    $theHeader->{sample_offset} = $HEADERSIZE;
    
    # bases are stored after the samples
    $theHeader->{bases} = scalar @{$self->{Bases}};
    $theHeader->{bases_offset} = $theHeader->{sample_offset} +
                      4*$theHeader->{sample_size}*$theHeader->{samples};

    # after the interactive editor, there are sometimes spurious \n's
    # at the end of comments or private. We want there to be a final \n
    # at the end of things, but \n should not be the only character in the
    # whole field
    $$theComment =~ s/\s*$//;       # trim all trailing white space and add one
    $$theComment =~ s/(\S)$/$1\n/;  # to the end if there is a non-whitespace 
    $$thePrivate =~ s/\s*$//;       # trim all trailing white space and add one
    $$thePrivate =~ s/(\S)$/$1\n/;  # to the end if there is a non-whitespace 

    # comments are after the bases
    $theHeader->{comments_size} = length($$theComment);
    $theHeader->{comments_offset} = $theHeader->{bases_offset} +
               12*$theHeader->{bases} ;

    # private data is next. if private_size is zero, we won't
    # change the size of the offset. (sometimes this is originally 0)
    $theHeader->{private_size} = length($$thePrivate);
    if($theHeader->{private_size} != 0) {
        $theHeader->{private_offset} = $theHeader->{comments_offset} +
               $theHeader->{comments_size} ;
    }
         
    # the others code_set, bases_left_clip and bases_right_clip are
    # irrelevent and we do not need to check them. but they should be defined
    # private_offset may be undefined if private_size is zero.
    foreach $key ("code_set","bases_left_clip","bases_right_clip",
                                                   "private_offset") {
        if (!defined($theHeader->{$key}) ) {
            $theHeader->{$key} = 0;
        }
    }
                
    # make sure the data is scaled properly. If it is too big, divide by
    # the proper number to make it so.
    for($i=0,$dataMax=0;$i<$theHeader->{samples};$i++) {
        $dataMax = ($dataMax>$theData->{A}[$i])?$dataMax:$theData->{A}[$i];
        $dataMax = ($dataMax>$theData->{C}[$i])?$dataMax:$theData->{C}[$i];
        $dataMax = ($dataMax>$theData->{G}[$i])?$dataMax:$theData->{G}[$i];
        $dataMax = ($dataMax>$theData->{T}[$i])?$dataMax:$theData->{T}[$i];
    }
    if ($dataMax > ((1<<(8*$theHeader->{sample_size}))-1) ) { # gotta scale
        my $scale  = ((1<<(8*$theHeader->{sample_size}))-1)/$dataMax;
        print STDERR "datamax is $dataMax is above max, scaling by $scale.\n";
        for($i=0;$i<$theHeader->{samples};$i++) {
            $self->{Data}{A}[$i] = int($scale*$self->{Data}{A}[$i] + .5);
            $self->{Data}{C}[$i] = int($scale*$self->{Data}{C}[$i] + .5);
            $self->{Data}{G}[$i] = int($scale*$self->{Data}{G}[$i] + .5);
            $self->{Data}{T}[$i] = int($scale*$self->{Data}{T}[$i] + .5);
        }
    }

    # there are more checks we could do. Like the peaks are in the proper
    # order, the called bases are A,C,G,T,N,-...
    
}

sub error {
    # error messages to be investigated are put on this stack
    # if called with an argument, that is pushed onto the end of
    # the stack. Whether there is an argument or not, the function
    # returns the number of errors in the fifo.

    my $self = shift;
    my $line = shift;
    push @{$self->{Messages}}, $line if( defined($line) );

    return scalar(@{$self->{Messages}});
}

sub errorMessage {
    # removes and return the first message from the error fifo.
    # if there is no message, this returns undef.
    my $self = shift;

    return shift(@{$self->{Messages}}) if (scalar(@{$self->{Messages}}));
    return undef;
}

# various io utilities. we'll need to have some that are sure to be
# endian independent and work from unsigned ints of different sizes.

# convert a vector of data to an unsigned int
# the data is a vector of elements; each element is split into bytes
# and the whole thing is digested into an unsigned int.

sub toUInt {

    # the supplied argument is a multibyte scalar, or list of same.
    # the byte order in ABI files is alway big-endian
    my $D = join('',@_);
    my @nextD;
    my $v = 0;
    if( length($D) == 1) {
        return ord $D;
    } elsif ( length($D) == 2) {
        my $retVal = unpack('n',$D);
        return ($retVal<0)?$retVal+32768:$retVal;
    } elsif ( length($D) == 4) {
        my $retVal = unpack('N',$D);
        return ($retVal<0)?$retVal+4294967296:$retVal;
    } else {
        while ($D = shift) {
            @nextD = split('',$D);
            while(@nextD) {
                $v *= 256;
                $v += ord $nextD[0];
                shift @nextD;
            }
        }
        return $v;
    }
}

sub fromUInt {
    # convert an unsigned int with into a n byte field

    my $v = shift;
    my $n = shift;
    #if( $n == 1) {
    #    return pack("C",$v);
    #} elsif ($n == 2) {
    #    return pack("S",$v);
    #} elsif ($n == 4) {
    #    return pack("I",$v);
    #} elsif ($n == 8) {
    #    return pack("L",$v);
    #} else {
        my @s = ();

        while ($n) {
            unshift @s,chr($v&0xff);
            $v = $v >> 8;
            $n--;
        }

        return join('',@s);
    #}

}

sub chromat_type {
    my $file = shift;
    open(FILE,"<$file") or ($! = "Cannot open $file" && return);
    binmode FILE;
    # look for scf by reading 4 bytes
    use EditTrace::SCFData;
    if(read(FILE,$Header,4) == 4 && $Header eq $EditTrace::SCFData::SCF_MAGIC) {
            close FILE;
            return "EditTrace::SCFData";
    }         
    # restart from 0 and determine abi files by the magic number
    seek FILE, 0, 0;
    use EditTrace::ABIData;
    if(read(FILE,$Header,4) == 4 && $Header eq $EditTrace::ABIData::ABI_MAGIC) {
            close FILE;
            return "EditTrace::ABIData";
    }    
    # restart from 0 and determine sff files by the magic number
    seek FILE, 0, 0;
    use EditTrace::SFFData;
    if(read(FILE,$Header,4) == 4 && $Header eq $EditTrace::SFFData::SFF_MAGIC) {
            close FILE;
            return "EditTrace::SFFData";
    }    
    return;
}

1;
