=head1 Name

   PhredInterface.pm  A module for running/storing/retreiving phred base calls

=head1 Usage

   use PhredInterface;
   $phred = new PhredInterface([options])

   $phred->set_options([options]);
   $phred->run($sequence);
   $baseCalls = $phred->seq_file();
   $quality = $phred->qual_file();

=head1 Options

=cut

package PhredInterface;

use strict;
use Pelement;
use PCommon;
use Files;
use Getopt::Long;
use PelementDBI;

=head1 Public Methods

=cut

sub new 
{
  my $class = shift;

  # we require an argument to specify the session)
  my $sessionHandle = shift ||
                     die "Session handle required for Phred interface";

  # the default database
  my $phred_exe = $GENOMIC_BIN."/phred";
  my $options = "-process_nomatch";
  my $seq = Files::make_temp("phred.seq.XXXX");
  my $qual = Files::make_temp("phred.qual.XXXX");
  my $error = Files::make_temp("phred.error.XXXX");
  my $chromat = '';

  # we'll look for a hash of optional arguments
  my $args = shift;
  if ($args) {
    $chromat  = PCommon::parseArgs($args,"chromat");
  }


  my $self = {
              "session"   => $sessionHandle, 
              "phred_exe" => $phred_exe,
              "options"   => $options,
              "seq"       => $seq,
              "qual"      => $qual,
              "chromat"   => $chromat,
              "error"     => $error,
             };
  
  return bless $self, $class;
}

=head1 run

  Execute the phred command. The argument is a chromatogram

=cut

sub run
{
  my $self = shift;
  my $seq = shift;

  $self->session->error("No file specified","No file specified for phred")
                                                     unless $self->{chromat};

  my $file = $self->{chromat};
  # we need to clean up special characters in file names
  $file =~ s/([()\s?*])/\\$1/g;

  my $cmd = $self->{phred_exe}." ".$self->{options}." ";
  $cmd .= "-sa ".$self->{seq}." -qa ".$self->{qual}."  $file";
  $cmd .= " 2> ".$self->{error};

  &PCommon::shell($cmd);
}

sub session    { shift->{session}; }
sub seq_file   { shift->{seq}; }
sub qual_file  { shift->{qual}; }
sub error_file { shift->{error}; }

    
sub DESTROY
{
  my $self = shift;
  unlink($self->seq_file) if $self->seq_file;
  unlink($self->qual_file) if $self->qual_file;
  unlink($self->error_file) if $self->error_file && -z $self->error_file;
}
  
1;

