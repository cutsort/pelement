=head1 Name

NCBIBlastInterface.pm 

Use NCBI Blast to find MSPs. Uses same API as BlastInterface.pm.

=head1 NOTES

Uses the Bio::Tools::Run::StandAloneBlastPlus wrapper from BioTools.
Some relevant links:

  http://www.bioperl.org/wiki/HOWTO:BlastPlus
  http://www.bioperl.org/wiki/HOWTO:SearchIO
  http://search.cpan.org/~cjfields/BioPerl-Run-1.006900/lib/Bio/Tools/Run/StandAloneBlastPlus.pm
  http://www.bioperl.org/wiki/Parsing_BLAST_HSPs

Supported NCBI Blast+ Matrices:

  BLOSUM80 
  BLOSUM62  (default)
  BLOSUM50 
  BLOSUM45 
  PAM250 
  BLOSUM90 
  PAM30 
  PAM70 

=cut


package NCBIBlastInterface;

use strict;
no strict 'refs';

use File::Temp;
use List::Util qw(min max);
use FileHandle;
use File::Basename qw(basename dirname);
use POSIX qw(strftime);

use String::ShellQuote qw(shell_quote);
use Text::ParseWords qw(shellwords);
use IO::String;
use Bio::SeqIO;
use Bio::Tools::Run::StandAloneBlastPlus;

use Session;

# project-specific settings
use Pelement;
our $blast_dir = $NCBI_BLAST_BIN_DIR;
our $db_dir = $BLAST_DB;
our $tmp_dir = $PELEMENT_TMP;
our $default_parser = \&na_arms_parser;
our $default_database = $db_dir."release3_genomic";
our %wublast_defaults;
$wublast_defaults{blastn} = {
  -reward=>5,
  -penalty=>-4,
  -gapopen=>10,
  # 10 is actually the wublast default, but NCBI Blast doesn't support
  # the 5,-4,10,10 combination. So change this to 6.
  #-gapextend=>10,
  -gapextend=>6,
  -word_size=>11,
};
our %default_options;
$default_options{blastn} = { 
  -reward=>1,
  -penalty=>-2,
  -dust=>'yes',
  -xdrop_ungap=>6,
  -xdrop_gap=>25,
  -gapopen=>7,
  -gapextend=>2,
  -word_size=>7,
};

sub new 
{
  my $class = shift;
  my $session = shift
    or die "Session handle required for blast interface";
  my $args = shift || {};

  my $self = {
    session=>$session,
    query_string => scalar parseArgs($args, 'query_string'),
    subject_string => scalar parseArgs($args, 'subject_string'),
    query => scalar parseArgs($args, 'query'),
    subject => scalar parseArgs($args, 'subject'),
    db => scalar parseArgs($args, 'db'),

    subject_parser => scalar parseArgs($args, 'parser'),
    program => scalar parseArgs($args, 'program'),
    output => scalar parseArgs($args, 'output'),
    error => scalar parseArgs($args, 'error'),
    max_hsp => scalar parseArgs($args, 'max_hsp'),
    max_sub => scalar parseArgs($args, 'max_sub'),
    options => scalar(parseArgs($args, 'ncbi_options')) || scalar(parseArgs($args, 'options')),
    protocol => scalar parseArgs($args, 'protocol'),
    clean_up => scalar parseArgs($args, 'clean_up'),
    path => scalar parseArgs($args, 'path'),
    min_hit_score => scalar parseArgs($args, 'min_hit_score'),
  };
  $self->{subject_parser} = $default_parser if !defined $self->{subject_parser};
  $self->{program} = 'blastn' if !defined $self->{program};
  $self->{options} = defined($self->{options})
    ? {%{$wublast_defaults{$self->{program}}||{}}, shellwords($self->{options})}
    : $default_options{$self->{program}}||{};
  # extract the min_hit_score pseudo-option
  $self->{$_} = delete $self->{options}{"-$_"} for qw(min_hit_score);

  $self->{output} = File::Temp->new(
    DIR=>$tmp_dir,
    TEMPLATE=>"blast_${$}_XXXXX",
    SUFFIX=>'.out',
    UNLINK=>0,
  )->filename if !defined $self->{output};
  $self->{error} = File::Temp->new(
    DIR=>$tmp_dir,
    TEMPLATE=>"blast_${$}_XXXXX",
    SUFFIX=>'.err',
    UNLINK=>0,
  )->filename if !defined $self->{error};

  $self->{max_hsp} = 50 if !defined $self->{max_hsp};
  $self->{max_sub} = 50 if !defined $self->{max_sub};
  $self->{clean_up} = 1 if !defined $self->{clean_up};
  $self->{path} = $blast_dir if !defined $self->{path};
  
  return bless $self, $class;
}

sub parseArgs
{
  my $argRef = shift;
  my $name = shift;

  # '-key' has precedence over 'key'
  return $argRef->{"-$name"} if exists $argRef->{"-$name"};
  return $argRef->{$name} if exists $argRef->{$name};
  return undef;
}

=head1 run

Execute the blast run.

=cut

sub run
{
  my $self = shift;
  my $seq = shift;
  my $session = $self->{session};

  my $query;
  my $subject;
  my $database;

  # choose the query source
  if ($seq && $seq->{fasta}) {
    $query = Bio::SeqIO->new(-file=>$seq->{fasta}, -format=>'fasta')->next_seq;
  }
  elsif ($self->{query_string}) {
    $self->{query_string} = ">query\n".$self->{query_string} if $self->{query_string} !~ /^>/;
    $query = Bio::SeqIO->new(-fh=>IO::String->new($self->{query_string}), -format=>'fasta')->next_seq;
  }
  elsif ($self->{query}) {
    $query = Bio::SeqIO->new(-file=>$self->{query}, -format=>'fasta')->next_seq;
  }
  else {
    $self->session->error("No query specified.");
    return 1;
  }
  $self->{query_name} = $query->display_id;

  # choose the subject source
  if ($self->{subject_string}) {
    $self->{subject_string} = ">subject\n".$self->{subject_string} if $self->{subject_string} !~ /^>/;
    $subject = Bio::SeqIO->new(-fh=>IO::String->new($self->{subject_string}), -format=>'fasta')->next_seq;
  }
  elsif ($self->{subject}) {
    $subject = Bio::SeqIO->new(-file=>$self->{subject}, -format=>'fasta')->next_seq;
  }
  elsif ($self->{db}) {
    $database = $self->{db};
  }
  else {
    $database = $default_database;
  }
  if (!$subject && !$database) {
    $session->error("No subject/database specified.");
    return 1;
  }

  # run blast
  my $factory = Bio::Tools::Run::StandAloneBlastPlus->new(
    -prog_dir=>$self->{path},
    -db_dir=>$tmp_dir,
  );
  $factory->no_throw_on_crash(1); # don't throw exceptions
  $self->{factory} = $factory;

  my $result;
  if ($database) {
    $database = $db_dir.$database if $database !~ /^\//;
    # We need to manually reach in and set _db_path. Trying to set it through
    # the StandaloneBlastPlus::new method causes the db name to get mangled.
    # This also lets us use -db_dir to set the directory for tempfiles without
    # also requiring the database to reside there.
    $factory->{_db_path} = $database;
    eval {
      $result = $factory->run(
        -method=>$self->{program}, 
        -query=>$query, 
        -method_args=>[%{$self->{options}||{}}],
        -outfile=>$self->{output},
      );
    };
  }
  else {
    eval {
      $result = $factory->bl2seq(
        -method=>$self->{program}, 
        -query=>$query, 
        -subject=>$subject, 
        -method_args=>[%{$self->{options}||{}}],
        -outfile=>$self->{output},
      );
    };
  }
  my $status = $?>>8;
  if ($@) {
    $session->warn($@);
    $status ||= 1;
  }

  # see if there were fatal error in this run. But we'll still record the
  # run even if it failed.
  $self->{stderr} = $factory->stderr;
  if ($self->{stderr}) {
    $session->warn($self->{stderr});
    $status ||= 1;
  }

  if ($self->{error}) {
    my $fh = FileHandle->new($self->{error},'w')
      or $session->die("Could not open $self->{error} for writing: $!");
    $fh->print($self->{stderr}) if $self->{stderr};
    $fh->close;
  }

  $self->{results} = [];
  if ($result) {
    push @{$self->{results}}, $result;
    while (my $result = $factory->next_result) {
      push @{$self->{results}}, $result;
    }
  }

  # log string representation of the blast parameters
  my @paramstring;
  my @parameters = $factory->get_parameters;
  for (my $i=0; $i<$#parameters; $i+=2) {
    push @paramstring, ("-$parameters[$i]",$parameters[$i+1])
      if $parameters[$i] ne 'command';
  }
  $self->{parameters} = \@parameters;
  $self->{command} = join(' ',
    shell_quote($factory->command),
    map {shell_quote($_)} @paramstring
  );

  $self->{blast_date} = strftime('%Y-%m-%d %H:%M:%S',
    $factory->blast_out && -e $factory->blast_out
    ? localtime((stat($factory->blast_out))[9])
    : localtime);

  return $status;
}

sub parse {
  my $self = shift;
  my $noinsert = $_[0] if @_ && $_[0] eq 'noinsert';
  my $session = $self->{session};

  $session->die("More than one result returned!") if @{$self->{results}} > 1;
  my $result = $self->{results}[0];

  # clean up the query and db a bit
  my $q_name = $result ? $result->query_name : $self->{query_name};
  $q_name =~ s/\s*\([0-9,]+ letters\)\s*$//;

  # if there was an error, we cannot parse the db name
  my $db_name = $result ? $result->database_name : $self->{db};
  $db_name =~ s/\Q$db_dir\E//;

  my $program_version = $result ? $result->algorithm_version : undef;

  # prepare the blast run record.
  my $bR = $self->session->Blast_Run({
      seq_name => $q_name,
      trace_uid => $q_name,
      subject_db => $db_name ,
      db => $db_name,
      program => basename($self->{program}),
      blast_time => $self->{blast_date},
      date => $self->{blast_date},
      run_datetime => $self->{blast_date},
      protocol => $self->{protocol} || 'unknown', 
      program_version => $program_version,
    });
  # prepare these containers for results
  my $bHitSet = $session->Blast_HitSet;
  my $bHspSet = $session->Blast_HSPSet;

  return ($bR,$bHitSet,$bHspSet) if !$result;

  # see if there were fatal error in this run. But we'll still record the
  # run even if it failed.
  if ($self->{stderr}) {
    $bR->insert if !$noinsert;
    return ($bR,$bHitSet,$bHspSet);
  }

  my $hitCtr = 0;
  while (my $hit = $result->next_hit) {
    #next if defined($self->{min_hit_score}) && $hit->raw_score < $self->{min_hit_score};

    my $hit_tag = join('',
      '>',$hit->name,
      defined($hit->description) && $hit->description ne '' 
        ? (' ',$hit->description) : ());
    my $headH = $self->{subject_parser}->($hit_tag);

    # prepare the hit and add it to the set
    my $bH = $session->Blast_Hit({ 
        run_id => $bR->ref_of('id'),
        subject_name => $headH->{name},
        name => $headH->{name},
        descriptive_tag => $headH->{desc},
        description => $headH->{desc},
        db => $headH->{db},
        accession => $headH->{acc},
        subject_length => $hit->length,
      });

    my @hsps;
    while (my $hsp = $hit->next_hsp) {
      my $bHsp = $session->Blast_HSP({ 
          hit_id=>$bH->ref_of('id'),
          score=>$hsp->score,
          bits=>$hsp->bits,
          percent=>sprintf('%.1f',$hsp->percent_identity),
          match=>$hsp->num_identical,
          length=>$hsp->hsp_length,
          query_begin=>$hsp->strand('hit')<0? $hsp->end('query') : $hsp->start('query'),
          query_end=>$hsp->strand('hit')<0? $hsp->start('query') : $hsp->end('query'),
          subject_begin=>$hsp->start('hit'),
          subject_end=>$hsp->end('hit'),
          query_gaps=>$hsp->hsp_length-($bR->program eq 'blastx'? $hsp->length('query')/3 : $hsp->length('query')),
          subject_gaps=>$hsp->hsp_length-$hsp->length('hit'),
          # watch out for underflows (only in postgres?)
          p_val=>do {my $p=1-exp(-$hsp->evalue); $p<1e-300? 0.0: $p},
          query_align=>$hsp->strand('hit')<0? revcomp(uc($hsp->query_string)) : uc($hsp->query_string),
          match_align=>$hsp->strand('hit')<0? scalar(reverse(uc($hsp->homology_string))) : uc($hsp->homology_string),
          subject_align=>$hsp->strand('hit')<0? revcomp(uc($hsp->hit_string)) : uc($hsp->hit_string),
          strand=>$hsp->strand('hit')||1,
        });
      push @hsps, $bHsp;
    }
    if (@hsps) {
      $bHspSet->add($_) for @{[sort {$b->score<=>$a->score} @hsps]}[0..min($self->{max_hsp}-1,$#hsps)];
      $bHitSet->add($bH);
      $hitCtr++;
      last if $hitCtr > $self->{max_sub};
    }
  }

  if (!$noinsert) {
    $bR->insert;
    $bHitSet->insert;
    $bHspSet->insert;
  }
  return ($bR,$bHitSet,$bHspSet);
}

=head2 revcomp

Return the reverse-complemented sequence

=cut

sub revcomp {
  my ($sequence) = @_;
  $sequence =~ tr/ACGTacgt/TGCAtgca/;
  return scalar reverse $sequence;
}

=head1 DESTORY

  add to the default destructor to clean up files.

=cut

sub DESTROY
{
  my $self = shift;

  return unless $self->{clean_up};

  $self->session->verbose("Deleting temporary blast files.");
  unlink($self->{output}) or
         $self->session->warn("Trouble deleting ".$self->{output});
  unlink($self->{error}) or
         $self->session->warn("Trouble deleting ".$self->{error});
  $self->{factory}->cleanup() if $self->{factory};
}

=head1 Setters/Getters

=cut

sub parameters { $_[0]->{parameters} }
sub command { $_[0]->{command} }
sub session { $_[0]->{session} }
sub get_output_file { $_[0]->{output} }
sub get_error_file { $_[0]->{error} }
sub output { $_[0]->{output} }
sub error { $_[0]->{error} }

sub query
{
  my $self = shift;
  $self->{query} = $_[0] if $_[0];
  return $self->{query};
}
sub db
{
  my $self = shift;
  $self->{db} = $_[0] if $_[0];
  return $self->{db};
}

=head1 set_subject_parser

  Override the default code for parsing the subject line. This returns
  a reference to a hash of values for name, db, accession, description.

=cut

sub set_subject_parser
{
  my $self = shift;
  $self->{subject_parser} = shift;
}

=head1 simple_text_parser

  The simplest possible parser. This takes a single line header:
  >text <blah>

  And strips off a leading > and whitespace. The entire text is
  stored as the name and the description

=cut

sub simple_text_parser
{
  my $record = shift;
  $record =~ s/^>\s*//;
  $record =~ s/\s.*$//;
  my $hashRef = {name=>$record,desc=>$record};
  return $hashRef;
}

=head1 na_te_dros_parser

  somewhat more complex: The first field is the name, everything else is
  the description

=cut

sub na_te_dros_parser
{
  my $record = shift;

  my ($dbstring,$description);
  if( $record =~ /^>(.*?)\|([^|]*)$/ ) {
    $dbstring = $1;
    $description = $2;
  } else {
    $dbstring = $record;
  }

  # try to split this in key/value pairs
  my %lookup = split(/\|/,$dbstring);

  my $hashRef = {};
  $hashRef->{name} = $description;
  $hashRef->{desc} = $description;

  # a prioritized search of db id's
  if( exists($lookup{gb}) ) {
    $hashRef->{db} = 'gb';
    $hashRef->{acc} = $lookup{gb};
  } elsif ( exists($lookup{FB}) ) {
    $hashRef->{db} = 'FB';
    $hashRef->{acc} = $lookup{FB};
  } elsif ( exists($lookup{FlyBase}) ) {
    $hashRef->{db} = 'FlyBase';
    $hashRef->{acc} = $lookup{FlyBase};
  }

  if ($description) {
     $hashRef->{name} = $description;
     $hashRef->{name} =~ s/\s*(\S+).*/$1/;
  } else {
     $record =~ s/^>//;
     $hashRef->{name} = $record;
     $hashRef->{name} =~ s/\s*(\S+).*/$1/;
     $hashRef->{desc} = $record;
  }
  return $hashRef;
}

=head1 dmel_transcript_parser

  beginning in 4.3, primary id's are FBtr. We need to dig to find name or symbols.

=cut

sub dmel_transcript_parser
{
  my $record = shift;
  
  # as a backup, do a simple parse of this.
  my $hashRef = simple_text_parser($record);

  # now try a more sophisticated. first, split at first whitespace
  my ($primary,$secondary) = split(/\s+/,$record,2);

  # subsequent fields are separated by ;\s*'s, each of which is a key=value
  my @secondary = split(/\s*[;=]\s*/,$secondary);
  # only parse if this if we get an even number of fields
  my %secondary = @secondary[0..(2*int(scalar(@secondary)/2)-1)];

  # sometimes the keys are in different case!
  map { $secondary{lc($_)} = $secondary{$_} } keys %secondary;

  # the gene name is the description
  $hashRef->{name} = $secondary{name} if exists $secondary{name};

  # CG is buried in the annotation
  $hashRef->{desc} = $1 if exists $secondary{dbxref} && $secondary{dbxref} =~ /IDs:([^,]*)/;

  # some long lines have spaces
  $hashRef->{name} =~ s/\s//g;
  $hashRef->{desc} =~ s/\s//g;

  # and a label for the primary FlyBase id
  $hashRef->{db} = 'FlyBase';
  $hashRef->{acc} = $primary;

  return $hashRef;
}

=head1 na_arms_parser

  The simplest possible parser. This takes a single line header
  >text

  And strips off a leading > and whitespace

=cut

sub na_arms_parser
{
  my $record = shift;
  $record =~ s/^>\s*//;
  $record =~ s/\s+$//;
  my $hashRef = {name=>$record};
  return $hashRef;
}

=head1 na_geno_dros_RELEASE3_parser

  The default subject line parser. The assumed format is:
  >gadfly|SEG:AE999999.Fake|gb|AE999999.Fake|arm:2L [1,9988]

  The return is a reference to a hash with name, accession, db, and the
  description line.

=cut

sub na_geno_dros_RELEASE3_parser
{
  my $record = shift;

  my ($dbstring,$description);
  if( $record =~ /^>(.*?)\|([^|]*)$/ ) {
    $dbstring = $1;
    $description = $2;
  } else {
    $dbstring = $record;
  }

  # try to split this in key/value pairs
  my %lookup = split(/\|/,$dbstring);

  my $hashRef = {};
  $hashRef->{name} = 'Unidentifed Sequence';
  $hashRef->{desc} = $description;
  if( exists($lookup{gb}) ) {
    $hashRef->{db} = 'gb';
    $hashRef->{acc} = $lookup{gb};
    $hashRef->{name} = $lookup{gb};
  } 
  if( exists($lookup{gadfly}) ) {
    $hashRef->{name} = $lookup{gadfly};
  }
  return $hashRef;
}


1;

