#
# the SCFData module for handling SCF data structures and file io
#
# History
#
#           01 Dec 00 jwc Initial release
#
#
package EditTrace::SCFData;

# the superclass EditTrace::TraceData will be used for reading/writing the
# generic data structure information from or to the terminal or an
# ascii file
use EditTrace::TraceData;
@ISA = (qw(EditTrace::TraceData));

# an SCF file consists of 4 segments: a Header of 128 bytes,
# a Data segment, a Comment segment and a Private segment.
# we will store the Header as a hash of (key,value) pairs.
# Data is a Hash of 4 arrays for A, C, G and T.
# Comment and Private data are unspecified; we will use scalar variables
# to hold these values.

# here is a default "dummy" scf file which will be the basis
# until we read one. This will be a template in case we want to
# create one from scratch

BEGIN {
    # parameters needed from the spec for SCF files
    # the magic number identifying a SCF file
    $SCF_MAGIC = ".scf";
    $HEADERSIZE = 128;
}

sub new {
    
    # the constructor just calls the superclass constructor and sets
    # the type.
    my $class = shift;
    # call the superclass contructor
    my $self = new EditTrace::TraceData;

    # set the type field in the header
    $self->{Header}->{type} = "scf";

    return bless $self,$class;
}

sub readFile {

    # arguments are the SCFData structure and a file name
    my $self = shift;
    my $inputFile = shift;
    my @sections = @_;

    # If no list of sections is specified in the call, read 'em all.
    @sections = (qw(Data Bases Comment Private)) if (!(scalar @sections));


    my ($Buffer,$readSize,$base,$Ap,$Cp,$Gp,$Tp,$peak,$i);

    # and here are the instances of the header, data, comments and private
    my $theHeader = $self->{Header};
    my $theData = $self->{Data};
    my $theBases = $self->{Bases};
    my $theComment = $self->{Comment};
    my $thePrivate = $self->{Private};

    # try to read. return 0 if this is not possible
    open(SCFFILE,"<$inputFile") || return 0;
    # set to binary mode just to be sure
    binmode SCFFILE;

    if( read(SCFFILE,$Buffer,$HEADERSIZE) != $HEADERSIZE ) {
        $self->error("This does not appear to be a SCF file.");
        return 0;
    }

    if( substr($Buffer,0,4) ne $SCF_MAGIC) {
        $self->error("This does not have a SCF file magic number.");
        return 0;
    }


    $theHeader->{samples}          =    vec($Buffer, 1,32);
    $theHeader->{sample_offset}    =    vec($Buffer, 2,32);
    $theHeader->{bases}            =    vec($Buffer, 3,32);
    $theHeader->{bases_left_clip}  =    vec($Buffer, 4,32);
    $theHeader->{bases_right_clip} =    vec($Buffer, 5,32);
    $theHeader->{bases_offset}     =    vec($Buffer, 6,32);
    $theHeader->{comments_size}    =    vec($Buffer, 7,32);
    $theHeader->{comments_offset}  =    vec($Buffer, 8,32);
    $theHeader->{version}          = substr($Buffer,36, 4) ;
    $theHeader->{sample_size}      =    vec($Buffer,10,32);
    $theHeader->{code_set}         =    vec($Buffer,11,32);
    $theHeader->{private_size}     =    vec($Buffer,12,32);
    $theHeader->{private_offset}   =    vec($Buffer,13,32);
    # the remaining bytes are not used
    # sample_size is either "1" for 1 byte, or "2" for 2 bytes/sample
    # 4 is the number of bases
    $readSize = 4*$theHeader->{samples}*$theHeader->{sample_size};

    # *******************************************************************
    # * DATA SECTION
    # *******************************************************************
    if (grep /Data/i,@sections)
    {
    seek SCFFILE, $theHeader->{sample_offset}, 0;
    if( read(SCFFILE,$Buffer,$readSize) != $readSize ) {
        $self->error("Trouble reading the data from the SCF file.");
        return 0;
    }
    # sample points are in different order for 2.0 and 3.0
    if ($theHeader->{version} < 3.0) {
      for($i=0;$i<length($Buffer)/$theHeader->{sample_size};) {
        push @{$theData->{A}},vec($Buffer,$i++,8*$theHeader->{sample_size});
        push @{$theData->{C}},vec($Buffer,$i++,8*$theHeader->{sample_size});
        push @{$theData->{G}},vec($Buffer,$i++,8*$theHeader->{sample_size});
        push @{$theData->{T}},vec($Buffer,$i++,8*$theHeader->{sample_size});
      }
    } else {
      for($i=0;$i<$theHeader->{samples};) {
        push @{$theData->{A}},vec($Buffer,$i++,8*$theHeader->{sample_size});
      }
      for(;$i<2*$theHeader->{samples};) {
        push @{$theData->{C}},vec($Buffer,$i++,8*$theHeader->{sample_size});
      }
      for(;$i<3*$theHeader->{samples};) {
        push @{$theData->{G}},vec($Buffer,$i++,8*$theHeader->{sample_size});
      }
      for(;$i<4*$theHeader->{samples};) {
        push @{$theData->{T}},vec($Buffer,$i++,8*$theHeader->{sample_size});
      }
      # now these need to be un-delta'ed
      foreach $base (qw(A C G T)) {
        $p_sample = 0;
        for($i=0;$i<$theHeader->{samples};$i++) {
          $theData->{$base}[$i] += $p_sample;
          $theData->{$base}[$i] %= ($theHeader->{sample_size}==2)?65536:256;
          $p_sample = $theData->{$base}[$i];
        }
        $p_sample = 0;
        for($i=0;$i<$theHeader->{samples};$i++) {
          $theData->{$base}[$i] += $p_sample;
          $theData->{$base}[$i] %= ($theHeader->{sample_size}==2)?65536:256;
          $p_sample = $theData->{$base}[$i];
        }
      }
    }
    }

    # *******************************************************************
    # * BASES SECTION
    # *******************************************************************
    if (grep /Bases/i,@sections)
    {
    $readSize = 12*$theHeader->{bases};
    seek SCFFILE, $theHeader->{bases_offset}, 0;
    if( read(SCFFILE,$Buffer,$readSize) != $readSize ) {
        $self->error("Trouble reading the bases from the SCF file.");
        return 0;
    }

    # sequence and quality are different for 2.0 and 3.0
    if ($theHeader->{version} < 3.0) {
      for($i=0;$i<$theHeader->{bases};$i++) {
          $peak =    vec($Buffer, 3*$i  ,32);
          $Ap =      vec($Buffer,12*$i+4, 8);
          $Cp =      vec($Buffer,12*$i+5, 8);
          $Gp =      vec($Buffer,12*$i+6, 8);
          $Tp =      vec($Buffer,12*$i+7, 8);
          $base = substr($Buffer,12*$i+8,1);
          $theBases->[$i] = {base=>$base,Ap=>$Ap,Cp=>$Cp,Gp=>$Gp,Tp=>$Tp,
                                              peak=>$peak};
      }
    } else {
      for($i=0;$i<$theHeader->{bases};$i++) {
          $peak =    vec($Buffer,                      $i,32);
          $Ap =      vec($Buffer,4*$theHeader->{bases}+$i, 8);
          $Cp =      vec($Buffer,5*$theHeader->{bases}+$i, 8);
          $Gp =      vec($Buffer,6*$theHeader->{bases}+$i, 8);
          $Tp =      vec($Buffer,7*$theHeader->{bases}+$i, 8);
          $base = substr($Buffer,8*$theHeader->{bases}+$i, 1);
          $theBases->[$i] = {base=>$base,Ap=>$Ap,Cp=>$Cp,Gp=>$Gp,Tp=>$Tp,
                                              peak=>$peak};
      }
    }
    }

    # *******************************************************************
    # * COMMENT SECTION
    # *******************************************************************
    if (grep /Comment/i,@sections)
    {
    seek SCFFILE, $theHeader->{comments_offset}, 0;
    if( read(SCFFILE,$$theComment,$theHeader->{comments_size})
                                  != $theHeader->{comments_size} ) {
        $self->error("Trouble reading the comments from the SCF file.");
        return 0;
    }
    }
 
    # *******************************************************************
    # * PRIVATE SECTION
    # *******************************************************************
    if (grep /Private/i,@sections)
    {
    seek SCFFILE, $theHeader->{private_offset}, 0;
    if( read(SCFFILE,$$thePrivate,$theHeader->{private_size})
                                   != $theHeader->{private_size} ) {
        $self->error("Trouble reading the private data from the SCF file.");
        return 0;
    }
    }

    close SCFFILE;

    # we are success
    return 1;
}

1;
