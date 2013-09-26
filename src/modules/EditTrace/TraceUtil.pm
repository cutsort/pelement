package EditTrace::TraceUtil;

    # this package contains various convenience routines
    # for trace file utilities.

use EditTrace::ABIData;
use EditTrace::TraceData;
use File::Basename;
@ISA = ("EditTrace::TraceData");

sub Abi2Scf {

    # a call for opening an ABI file, checking and saving it.
    # since we cannot save in ABI format, this will convert to SCF format.

    # the return from this routine is a list of values; the last value is
    # a number, either 0 for failure or 1 for success. The preceeding
    # messages are the error messages.

    # a quick error determination can be done by calling this and looking
    # at the result in a scalar context. 0 is failure and 1 is success.
    # for a more detailed report, evaluate the returned value in a list
    # context.

    my ($abiFile,$scfFile) = @_;

    if (!defined($abiFile) || !defined($scfFile) ) {
        return ("Parameters not specified",0);
    }

    # create an trace data structure.
    my $trace = new EditTrace::ABIData;

    # read the file
    if( ! $trace->readFile($abiFile) ) {
        # there are errors. push them onto a list and return them
        @errorList = ();
        while( $trace->error ) {
            push @errorList,$trace->errorMessage();
        }
        return (@errorList,0);
    }

    # make sure it is consistent
    $trace->check();

    # and write. we are only supporting SCF output at this point;
    # otherwise we need to do a real conversion
    
    if (! $trace->writeFile($scfFile) ) {
        return ("Cannot open $scfFile",0);
    }

    # hooray. we are success
    return 1;

}

sub dumpAllAbiInfo {
    # dump every element in the ABI dictionary. This is not needed
    # in routine use and is for investigational purposes only.

    # the argument is the name of an ABI file
    my $abiFile = shift;

    # create an trace data structure.
    my $trace = new EditTrace::ABIData;

    my ($tagType,$tagSize,$tagNumber,$tagLength,$tagData,@buffer);
    my ($dumpString);

    # read the file
    if( ! $trace->readFile($abiFile) ) {
        return ("Cannot open $abiFile",1);
    }

    # we need to reopen the file. this really ought to work since
    # we just had it opened
    open(ABIFILE,$abiFile) or die "Cannot open $abiFile.";

    # loop through the hashes and print out the elements
    my $theDictionary = $trace->{Dictionary};

    foreach my $Tag (sort keys %$theDictionary) {
        foreach my $Label (sort keys %{$theDictionary->{$Tag}}) {

            ($tagType,$tagSize,$tagNumber,$tagLength,$tagData) =
                                @{$theDictionary->{$Tag}{$Label}};
            # 18 is a string
            if($tagType == 18) { 
                # if it's short we read it directly.
                if ( $tagLength <= 4)  {
                    @buffer = split('',$tagData);
                    $tagLength = toUInt($buffer[0]);
                    $dumpString = "the string: ";
                    if( $tagLength ) {
                        $dumpString .= join('',@buffer[1..$tagLength]);
                    } else {
                        $dumpString .= "";   # this is a zero length string
                    }
                # otherwise we need use this as a file offset
                } else {
                    seek ABIFILE,toUInt($tagData),0;
                    if( read(ABIFILE,$tagLength,1) != 1 ) {
                        die "Trouble reading ABI length data.";
                    }
                    $tagLength = toUInt($tagLength);
                    if( read(ABIFILE,$dumpString,$tagLength) != $tagLength) {
                        die "Trouble reading ABI data.";
                    }
                    $dumpString = "the string: $dumpString";
                }

            # for the other data types, print it if there's only one,
            # otherwise we'll just print a count and the type
            } elsif ($tagType == 4) {
                if($tagNumber==1) {
                $dumpString = "the short integer ".(toUInt($tagData)>>16);
                } else {
                $dumpString = "$tagNumber short integers";
                }
            } elsif ($tagType == 5) {
                if($tagNumber==1) {
                $dumpString = "the long integer ".toUInt($tagData);
                } else {
                $dumpString = "$tagNumber long integer";
                }
            } elsif ($tagType == 7) {
                if($tagNumber==1) {
                    $tagData = toUInt($tagData);
                    # convert to IEEE float
                    my $fraction = $tagData & 0x7fffff;
                    my $exponent = ($tagData >> 23) & 0xff;
                    my $sign = ($tagData >> 31);
                    $tagData = ($sign?-1:1)*exp(log(2.0)*($exponent-127))*
                                (((1<<23)+$fraction)/(2**23));
                    $dumpString = sprintf "a float: %e", $tagData;
                 } else {
                    $dumpString = "$tagData floats";
                 }
            } elsif ($tagType == 10) {
                @buffer = split('',$tagData);
                $dumpString = sprintf "a date: %04d-%02d-%02d",
                       toUInt(@buffer[0..1]),toUInt($buffer[2]),
                       toUInt($buffer[3]);
            } elsif ($tagType == 11) {
                @buffer = split('',$tagData);
                $dumpString = sprintf "a time: %02d:%02d:%02d",
                       toUInt($buffer[0]),toUInt($buffer[1]),
                       toUInt($buffer[2]);
            } elsif ($tagType == 2) {
                $dumpString = "packed chars ".unpack("H8",$tagData);
            } else {
                $dumpString = "unknown data type: $tagType";
            }

            print "$Tag #$Label: $dumpString.\n";

        }
    }
    close(ABIFILE);
}

sub Abi2Phd
{
    # create the contents of a phd file based on the ABI calls and quality

    my $abiFile = shift;
    my $chromat = shift || (fileparse($abiFile))[0];

    if (!defined($abiFile)) {
        return ("File not specified",0);
    }

    # it might be SCF
    my $type = EditTrace::TraceData::chromat_type($abiFile);
    # create an trace data structure.
    my $trace = new $type;

    # read the file
    if( ! $trace->readFile($abiFile) ) {
        # there are errors. push them onto a list and return them
        @errorList = ();
        while( $trace->error ) {
            push @errorList,$trace->errorMessage();
        }
        return (@errorList,0);
    }

    # make sure it is consistent
    $trace->check();

    # and write. we are only supporting SCF output at this point;
    # otherwise we need to do a real conversion
    
    $bases = $trace->{Bases};
    return("No data",0) unless $#$bases;


    $contents = "BEGIN_SEQUENCE $chromat\n\nBEGIN_COMMENT\n";

    $contents .= "CHROMAT_FILE: $chromat\n";
    $contents .= "TIME: ".scalar(localtime(time()))."\n";
    $contents .= "CHEM: term\n";
    $contents .= "DYE: big\n\nEND_COMMENT\n\nBEGIN_DNA\n";

    foreach $i (0..$#$bases) {
      $contents .= lc($bases->[$i]{base})." ".
                   ($bases->[$i]{$bases->[$i]{base}.'p'} || '0').' '.
                   $bases->[$i]{peak}."\n";

    }

    $contents .= "END_DNA\n\nEND_SEQUENCE\n";
    
    # hooray. we are success
    return ($contents,($contents?1:0));

}

1;

