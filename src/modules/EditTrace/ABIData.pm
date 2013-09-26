#
# this module inherits most of its methods from TraceData.pm. The
# methods that must be supplied are new and readFile. writeFile and check
# are inherited since only the default output format (scf V2) is supported
#
#  History
#              01 Dec 00 jwc Initial version
#              23 Jan 01 jwc Error reporting expanded by implementing
#                            TraceData.pm error() and errorMessage()
#
#

package EditTrace::ABIData;

use EditTrace::TraceData;
@ISA = qw(EditTrace::TraceData);

# an ABI file contains an index at the end of the file with a series
# of 28 byte long entries. Each entry is a 4 byte tag followed by a counter.
# Following this is either a value or a pointer to the offset in the file
# where this is stored.

BEGIN {
    # parameters needed from the spec for ABI files
    # the magic number identifying a ABI file
    $ABI_MAGIC = "ABIF";
    $TAG_START = 26;      # offset in the file for index offset
    $TAG_COUNT = 18;      # offset in the file for the index count offset
    $TAG_LENGTH = 28;	  # size of each index entry
}

sub new {

    my $class = shift;
    # call the superclass contructor
    my $self = new EditTrace::TraceData;

    $self->{Header}->{type} = "abi";

    return bless $self,$class;
}

sub readFile {

    # arguments are the ABIData structure and a file name
    my $self = shift;
    my $inputFile = shift;
    my @sections = @_;

    # If no list of sections is specified in the call, read 'em all.
    @sections = qw(Data Bases Comment) if (!(scalar @sections));

    # and here are the instances of the header, data, comments and private
    my $theHeader = $self->{Header};
    my $theData = $self->{Data};
    my $theBases = $self->{Bases};
    my $theComment = $self->{Comment};
    my $thePrivate = $self->{Private};

    my ($i,$j,$fwo,@fwo,@base);

    # try to read. return 0 if this is not possible
    open(ABIFILE,"<$inputFile") ||
             ($self->error("Cannot open file $inputFile") && return 0);
    # set to binary mode just to be sure
    binmode ABIFILE;

    ($self->error("Trouble seeking to TAG_START.") && return 0) 
                                    if( !seek(ABIFILE,$TAG_START,0));
    
    ($self->error("Trouble reading ABI TAG_OFFSET data.") && return 0 ) 
                                    if( read(ABIFILE,$tagOffset,4) != 4 );
    $tagOffset = EditTrace::TraceData::toUInt($tagOffset);

    ($self->error("Trouble seeking to TAG_COUNT.") && return 0) 
                                    if( !seek(ABIFILE,$TAG_COUNT,0));
    
    ($self->error("Trouble reading ABI TAG_COUNT data.") && return 0 )
                                    if( read(ABIFILE,$tagCount,4) != 4 );
    $tagCount = EditTrace::TraceData::toUInt($tagCount);

    # this will return a double indexed hash of tag values
    # read it from the index.
    $self->{Dictionary} = readDictionary();

    # some basic information of # of samples, # of bases and precision.
    (undef,$theHeader->{sample_size},$theHeader->{samples}) =
                                        $self->readTag("DATA",9);
    (undef,undef,$theHeader->{bases}) = $self->readTag("PBAS",1);

    # the filter wheel order is stored as a set of characters
    # packed into the data field

    (undef,undef,undef,undef,$fwo) = $self->readTag("FWO_",1);
    @fwo = split('',$fwo);

    (undef,undef,undef,undef,$base[0]) = $self->readTag("DATA", 9);
    (undef,undef,undef,undef,$base[1]) = $self->readTag("DATA",10);
    (undef,undef,undef,undef,$base[2]) = $self->readTag("DATA",11);
    (undef,undef,undef,undef,$base[3]) = $self->readTag("DATA",12);

    # check for errors before we use any of those numbers
    (close(ABIFILE) && return 0) if ( $self->error() );

    # now @fwo and @base should line up. We just read them in
    # the @fwo entries are bases A, C, G and T in the order they
    # were read. @base are the offsets in the file for the corresponding
    # data

    $readSize = $theHeader->{sample_size}*$theHeader->{samples};

    # *******************************************************************
    # * DATA SECTION
    # *******************************************************************
    if (grep /Data/i,@sections)
    {
    while (@base) {
        seek ABIFILE,EditTrace::TraceData::toUInt($base[0]),0;
        ($self->error("Trouble reading ABI chromat data.") &&
                                           close(ABIFILE) && return 0 )
                          if( read(ABIFILE,$Buffer,$readSize) != $readSize );


        for($i=0;$i<$theHeader->{samples};$i++) {
            push @{$theData->{$fwo[0]}}, vec($Buffer,$i,16);
        }

#         Here is alternate code for this loop:
#         @Buffer = unpack("a2" x (length($Buffer)/2), $Buffer);
#         while (@Buffer) {
#             push @{$theData->{$fwo[0]}}, EditTrace::TraceData::toUInt($Buffer[0]);
#             shift @Buffer;
#         }
         shift @fwo; shift @base;
    }
    }

    # *******************************************************************
    # * BASES SECTION
    # *******************************************************************
    if (grep /Bases/i,@sections)
    {
    # the offset of the called bases information
    (undef,undef,undef,undef,$base) = $self->readTag("PBAS",1);
    seek ABIFILE, EditTrace::TraceData::toUInt($base), 0;
    ($self->error("Trouble reading ABI base data.") && 
                                         close(ABIFILE) && return 0 )
        if( read(ABIFILE,$Buffer,$theHeader->{bases}) != $theHeader->{bases} );
    @Bases = unpack("a1" x length($Buffer),$Buffer);

    # quality?
    (undef,undef,undef,undef,$qual) = $self->readTag("PCON",1);
    seek ABIFILE, EditTrace::TraceData::toUInt($qual), 0;
    ($self->error("Trouble reading ABI base data.") && 
                                         close(ABIFILE) && return 0 )
        if( read(ABIFILE,$Buffer,$theHeader->{bases}) != $theHeader->{bases} );
    @Quality = unpack("a1" x length($Buffer),$Buffer);

    # the offset of the base peak information
    # currently both base positions are 2 byte ints. But we'll read
    # this value and use it just because we can

    (undef,$readSize,undef,undef,$peak) = $self->readTag("PLOC",1);

    # this will trip up if there is no data. This will make
    # a file with not called bases instead
    if( defined($readSize) && $readSize > 0) {
        seek ABIFILE, EditTrace::TraceData::toUInt($peak), 0;
        ($self->error("Trouble reading ABI base location data.") &&
                                            close(ABIFILE) && return 0 )
              if( read(ABIFILE,$Buffer,$readSize*$theHeader->{bases}) !=
                                            $readSize*$theHeader->{bases} );
        @Buffer = unpack("a$readSize" x (length($Buffer)/$readSize),$Buffer);

        # base probability is assigned in the style of makeSCF 2.0; the
        # probability is 1 or 0 depending on whether it was called.
        # makeSCF 2.0 says an uncalled base is "-" with probability
        # 1 for all. Do we need to maintain this?
        $j = 0;
        while (@Bases) {
           $peak = EditTrace::TraceData::toUInt($Buffer[0]);
           # make an entry for Np to take the unassigned cases.
           ($Ap,$Cp,$Gp,$Tp,$Np) = (0,0,0,0,0);
           ${$Bases[0]."p"} = EditTrace::TraceData::toUInt($Quality[0]);
           $theBases->[$j] = {base=>$Bases[0],Ap=>$Ap,Cp=>$Cp,Gp=>$Gp,Tp=>$Tp,
                                         peak=>$peak};
           shift @Bases; shift @Buffer; shift @Quality;
           $j++;
        }
    }
    }
        
    # *******************************************************************
    # * COMMENT SECTION
    # *******************************************************************
    if (grep /Comment/i,@sections)
    {
    # initialize the comments
    $$theComment = "";

    # get the average signal strength information
    (undef,undef,undef,undef,$snOffset) = $self->readTag("S/N%",1);
    seek ABIFILE, EditTrace::TraceData::toUInt($snOffset), 0;
    ($self->error("Trouble reading ABI signal strength data.") && 
                                          close(ABIFILE) && return 0 )
                                       if( read(ABIFILE,$snString,8) != 8 );
    @snString = split('',$snString);
    $$theComment .= "avg_signal_strength =";
    # we need to use the fwo again.
    @fwo = split('',$fwo);
    while (@fwo) {
        $$theComment .= " ".$fwo[0].":".EditTrace::TraceData::toUInt(@snString[0..1]);
        shift @snString; shift @snString; shift @fwo;
    }
    $$theComment .= "\n";

    # read the abi comment field
    $$theComment .= "comments = ".$self->readString("CMNT")."\n";

    # the peak spacing information. This will be stored in the data field
    (undef,undef,undef,undef,$peakSpace) = $self->readTag("SPAC",1);
    $peakSpace = EditTrace::TraceData::toUInt($peakSpace);
    # convert to IEEE float
    $fraction = $peakSpace & 0x7fffff;
    $exponent = ($peakSpace >> 23) & 0xff;
    $sign = ($peakSpace >> 31);
    $peakSpace = ($sign?-1:1)*exp(log(2.0)*($exponent-127))*
                                (((1<<23)+$fraction)/(2**23));
    $$theComment .= sprintf "avg_spacing = %-6.2f\n", $peakSpace;

    $$theComment .= "machine_name = ".$self->readString("MCHN")."\n";
    $$theComment .= "dye_primer = ".$self->readString("PDMF")."\n";
    $$theComment .= "sample_name = ".$self->readString("SMPL")."\n";

    # start and stop date and time
    # the format used here is per ISO 8601. The Standard calls for a 'T'
    # character between date and time but that may be optionally omitted.
    # we are skipping it here and using a space
    # the format is YYYY-MM-DD HH:MM:SS where all numbers are zero padded
    (undef,undef,undef,undef,$theDate) = $self->readTag("RUND",1);
    @theDate = split('',$theDate);
    $$theComment .= sprintf "start_date = %04d-%02d-%02d",
                       EditTrace::TraceData::toUInt(@theDate[0..1]),EditTrace::TraceData::toUInt($theDate[2]),
                       EditTrace::TraceData::toUInt($theDate[3]);

    (undef,undef,undef,undef,$theDate) = $self->readTag("RUNT",1);
    @theDate = split('',$theDate);
    $$theComment .= sprintf " %02d:%02d:%02d\n",
                       EditTrace::TraceData::toUInt($theDate[0]),EditTrace::TraceData::toUInt($theDate[1]),
                       EditTrace::TraceData::toUInt($theDate[2]);

    (undef,undef,undef,undef,$theDate) = $self->readTag("RUND",2);
    @theDate = split('',$theDate);
    $$theComment .= sprintf "stop_date = %04d-%02d-%02d",
                       EditTrace::TraceData::toUInt(@theDate[0..1]),EditTrace::TraceData::toUInt($theDate[2]),
                       EditTrace::TraceData::toUInt($theDate[3]);

    (undef,undef,undef,undef,$theDate) = $self->readTag("RUNT",2);
    @theDate = split('',$theDate);
    $$theComment .= sprintf " %02d:%02d:%02d\n",
                       EditTrace::TraceData::toUInt($theDate[0]),EditTrace::TraceData::toUInt($theDate[1]),
                       EditTrace::TraceData::toUInt($theDate[2]);

    $$theComment .= "well = ".$self->readString("TUBE")."\n";

    # the model number
    (undef,undef,undef,undef,$mod) = $self->readTag("MODL",1);
    $$theComment .= "source = ".$mod."\n";


    # this writes the capillary info as lane = used/total

    (undef,undef,undef,undef,$mod) = $self->readTag("LANE",1);
    @mod = split('',$mod); $mod = EditTrace::TraceData::toUInt(@mod[0..1]);
    $$theComment .= "lane = ".$mod."/";
    (undef,undef,undef,undef,$mod) = $self->readTag("NLNE",1);
    @mod = split('',$mod); $mod = EditTrace::TraceData::toUInt(@mod[0..1]);
    $$theComment .= $mod."\n";
    }

    close ABIFILE;

    # we are success
    return 1;
}

sub readTag {
  
    # arguments:
    #        $Tag the label we're searching for
    #        $Label which occurance
    my $self = shift;
    my $Tag = shift;
    my $Label = shift;

    # variables used from caller:

    if( exists($self->{Dictionary}{$Tag}) && 
            exists($self->{Dictionary}{$Tag}{$Label}) ) {
        return @{$self->{Dictionary}{$Tag}{$Label}};
    } else {
        $self->error("Error: tag $Tag:$Label not present.");
        return (undef,undef,undef,undef,undef);
    }

}
#
# a tag in an abi file is a 4 character mnemonic followed by a 4 byte
# tag number which counts the occurance of that tag. Following this
# are 2 2-byte ints for data type and length of the data element,
# then 3 4-byte ints for 1) number of elements, 2) record length and
# 3) data. The third field is the data if the data is 4 bytes or
# less, or it is an offset in the file to where the data is stored.
# the data will be returned as a pair of short words converted to unsigned
# ints, 2 longwords converted to long unsigned ints and a 4 byte field
# unconverted
#

sub readDictionary {
  
    # variables used from caller:
    # ABIFILE opened filehandle
    # $tagOffset the position in the file for the tag index
    # $tagCount for the maxumum nuber of tags in the file
    # $TAG_LENGTH parameter of file format

    # local variables
    my ($buffer,@buffer,$counter);
    my ($tag,$tagLabel,$tagType,$tagSize,$tagNumber,$tagLength,$tagData);

    my $dictionary = {};
    # position ourselves at the start of the dictionary
    seek ABIFILE, $tagOffset, 0;

    # read the dictionary in one big chomp
    if( read(ABIFILE,$buffer,$tagCount*$TAG_LENGTH) != $tagCount*$TAG_LENGTH ) {
        $self->error("Error while reading ABI index.");
        return $dictionary;
    }

    # go through all the entries and load the dictionary
    for($counter=0;$counter<$tagCount;$counter++) {
        @buffer = unpack("a4 a4 a2 a2 a4 a4 a4",$buffer);
        $buffer = substr($buffer,$TAG_LENGTH);
        $tag       =        $buffer[0];
        $tagLabel  = EditTrace::TraceData::toUInt($buffer[1]);
        $tagType   = EditTrace::TraceData::toUInt($buffer[2]);
        $tagSize   = EditTrace::TraceData::toUInt($buffer[3]);
        $tagNumber = EditTrace::TraceData::toUInt($buffer[4]);
        $tagLength = EditTrace::TraceData::toUInt($buffer[5]);
        $tagData =          $buffer[6];
        if( !exists $dictionary->{$tag} ) {
            $dictionary->{$tag} = {};
        }
        $dictionary->{$tag}{$tagLabel} =
                         [$tagType,$tagSize,$tagNumber,$tagLength,$tagData];

       ## debug: for exploring all tags
       if( 0 ) {
         if ($tagType == 18 ) {
            if ( $tagLength <= 4) {
               print "Dictionary tag $tag with label $tagLabel is type ",
                     "$tagType, size $tagSize, number $tagNumber, length ",
                     "$tagLength and data $tagData.\n";
            } else {
               seek ABIFILE,$tagData,0;
               $bb = "<failed read>";
               read(ABIFILE,$bb,$tagLength);
               print "Dictionary tag $tag with label $tagLabel is type ",
                     "$tagType, size $tagSize, number $tagNumber, length ",
                     "$tagLength and data $bb.\n";
            }
         } else {
            print "Dictionary tag $tag with label $tagLabel is type ",
                  "$tagType, size $tagSize, number $tagNumber, length ",
                  "$tagLength and data... \n";
         }
      }
   }
   return $dictionary;
}

sub readString {
    # this is a utility routine which 1) finds and locates a $Tag which
    # is assumed to be stored as a string, 2) reads the length of the data
    # if the data is <= 4, then read the string from the data field, else
    # use the offset in the data to read the string and return it.
    # read a pointer to the comment

    my $self = shift;
    my $Tag = shift;
    my ($sLength,$sData,$theString,@sData,$which);

    # an optional second argument is which tag it is
    if (@_) {
        $which = shift;
    } else {
        $which = 1;
    }

    (undef,undef,undef,$sLength,$sData) = $self->readTag($Tag,$which);

    if (! defined($sLength) || ! defined($sData) ) {
        # uh-oh, not found
        $self->error("Cannot read string in ABI file.");
        return "";
    }
    # if the string is short enough, it's stored in the data
    if( $sLength <= 4 ) {
        @sData = split('',$sData);
        $sLength = EditTrace::TraceData::toUInt($sData[0]);
        if( $sLength ) {
            return join('',@sData[1..$sLength]);
        } else {
            return "";   # this is a zero length string
        }
    } else {
    # if the string is longer, this is an offset
        seek ABIFILE,EditTrace::TraceData::toUInt($sData),0;
        ($self->error("Trouble reading ABI length data.") && return "" )
                                        if( read(ABIFILE,$sLength,1) != 1 );
        $sLength = EditTrace::TraceData::toUInt($sLength);
        ($self->error("Trouble reading ABI length data.") && return "" )
                          if( read(ABIFILE,$theString,$sLength) != $sLength);
        return $theString;
    }
}

1;
