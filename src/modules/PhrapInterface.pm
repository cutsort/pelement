=head1 Name

   PhrapInterface.pm  A module for running/storing/retreiving phrap assemblies

=head1 Usage

   use PhrapInterface
   $phrap = new PhrapInterface($session,[options])

   $phrap->set_options([options]);
   $blast->run($fastaFile);
   $contigs = $phrap->contigs
   $singlets = $phrap->singlets;
   $ace = $phrap->ace;

=head1 Options

=cut

package PhrapInterface;

use strict;
use Pelement;
use PCommon;
use Files;

=head1 Public Methods

=cut

sub new
{
  my $class = shift;

  # we require an argument to specify the session)
  my $sessionHandle = shift ||
                     die "Session handle required for blast interface";

  # the default setup
  my $program = $PELEMENT_PHRAPBIN;
  my $options = ' -retain_duplicates -vector_bound 0 -minscore 8 -minmatch 8 -raw -word_raw ';
  my $file = '';
  my $save = 0;

  # we'll look for a hash of optional arguments
  my $args = shift;
  if ($args) {
    $program = $args->{-program} if exists($args->{-program});
    $options = $args->{-options} if exists($args->{-options});
    $file    = $args->{-file}    if exists($args->{-file});
    $save    = $args->{-save}    if exists($args->{-save});
  }

  my $self = {
              "session" => $sessionHandle,
              "file"    => $file,
              "program" => $program,
              "options" => $options,
              "save"    => $save,
              "output"  => '/dev/null',
              "error"   => '/dev/null',
             };

  return bless $self, $class;
}


=head1 run

  Execute the phrap command. The argument is a multi-fasta file if
  the 'file' option was not specified.

=cut

sub run
{
  my $self = shift;
  my $file = shift || $self->{file};

  ($self->session->error("No fasta file saved.") and return) unless $file;
  my $cmd = $self->{program}." ".$self->{options}." ".$file;
  $cmd .= " > ".$self->{output}." 2> ".$self->{error};

  &PCommon::shell($cmd);

  $self->{ace} = $file.".ace" if -e $file.".ace";
  $self->{singlets} = $file.".singlets" if -e $file.".singlets";
  $self->{contigs}  = $file.".contigs" if -e $file.".contigs";

  # figure out a more better return value later.
  return 1;
}
=head1 contigs

   In a scalar context, returns the number of contigs; in a list
   context returns a hash'able list of (contig,sequence) names

=cut
sub contigs
{
   my $self = shift;

   return unless -e $self->{contigs};

   return $self->fileRead($self->{contigs});
}
sub singlets
{
   my $self = shift;

   return unless -e $self->{singlets};

   return $self->fileRead($self->{singlets});
}
sub fileRead
{
   my $self = shift;
   my $file = shift;

   open(FIL,$file) || $self->session->die("File Open","Cannot open $file");
   my @ret = ();
   my $ret = 0;
   my $lastName = '';
   my $lastSeq = '';
   while (<FIL>) {
      chomp $_;
      if ($_ =~ /^>\s*(\S+)/ ) {
         if (wantarray) {
            push @ret,$lastName,$lastSeq if $lastSeq && $lastName;
            $lastName = $1;
            $lastSeq = '';
         } else {
            $ret++;
         }
      } else {
         $lastSeq .= $_;
      }
   }
   close(FIL);

   push @ret,$lastName,$lastSeq if $lastSeq && $lastName;

   return @ret if wantarray;
   return $ret;
}

=head1 session

   Returns the session object.

=cut
sub session      { shift->{session}; }


=head1 DESTORY

  add to the default destructor to clean up files.

=cut
sub DESTROY
{
   my $self = shift;

   return if $self->{save};

   $self->session->info("Deleting temporary phrap files.");

   foreach my $ext qw( .singlets .qual .problems.qual .problems .log .contigs .contigs.qual .ace ) {
      if( -e $self->{file}.$ext ) {
         unlink($self->{file}.$ext) or
             $self->session->warn("Trouble deleting ".$self->{file}.$ext);
      }
   }
   if( -e $self->{file} ) {
      unlink($self->{file}) or
             $self->session->warn("Trouble deleting ".$self->{file});
   }

}

1;
