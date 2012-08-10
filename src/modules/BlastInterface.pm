=head1 Name

   BlastInterface.pm  A module for running/storing/retreiving blast results

=head1 Usage

   use Blast;
   $blast = new BlastInterface([options])

   $blast->set_options([options]);
   $blast->run($sequence);
   $result = $blast->file();
   $session->at_exit({unlink $results});
   $blast->set_subject_parser(\&parser);
   $blast_sql = $blast->to_sql($result);
   $session->db->do($blast_sql);
   
   or for the last 2 steps (improved)
   ($run,$hitset,$hspset) = $blast->parse

=head1 Options

=cut

package BlastInterface;

use strict;
use Pelement;
use PCommon;
use Files;
use Blast_Run;
use Blast_Hit;
use Blast_HSP;
use Blast_HitSet;
use Blast_HSPSet;
use lib $FLYBASE_MODULE_PATH;
use Getopt::Long;
use DBI;

use lib '/usr/local/bdgp/lib/perl';
use BPlite;

=head1 Public Methods

=cut

sub new 
{
  my $class = shift;

  # we require an argument to specify the session)
  my $sessionHandle = shift ||
                     die "Session handle required for blast interface";

  # the default database
  my $db = $BLAST_DB."release3_genomic";
  my $parser = \&na_arms_parser;
  my $program = $BLAST_PATH."blastn";
  my $options = "m=1 n=-2 x=6 gapx=25 q=7 r=2 gapL=1.37 gapK=.711 gapH=1.31 W=7 -filter dust ";
  my $output = &Files::make_temp("blast_".$$."_XXXXX.out");
  my $error  = &Files::make_temp("blast_".$$."_XXXXX.err");
  my $min_sub = 1;
  my $max_sub = 50;
  my $min_hsp = 1;
  my $max_hsp = 50;
  my $clean_files = 1;

  # we'll look for a hash of optional arguments
  my $args = shift;
  if ($args) {
    $db = $args->{-db} if exists($args->{-db});
    $parser = \&{$args->{-parser}} if exists($args->{-parser});
    $program = $args->{-program} if exists($args->{-program});
    $output = $args->{-output} if exists($args->{-output});
    $error = $args->{-error} if exists($args->{-error});
    $min_sub = $args->{-min_sub} if exists($args->{-min_sub});
    $max_sub = $args->{-max_sub} if exists($args->{-max_sub});
    $min_hsp = $args->{-min_hsp} if exists($args->{-min_hsp});
    $max_hsp = $args->{-max_hsp} if exists($args->{-max_hsp});
    $options = $args->{-options} if exists($args->{-options});
  }

  $db = $BLAST_DB.$db unless $db =~ /^\//;

  my $self = {
              "subject_parser"=>$parser,
              "session" => $sessionHandle, 
              "db"      => $db,
              "program" => $program,
              "options" => $options,
              "output"  => $output,
              "error"   => $error,
              "min_sub" => $min_sub,
              "max_sub" => $max_sub,
              "min_hsp" => $min_hsp,
              "max_hsp" => $max_hsp,
              "clean_up"=> $clean_files,
             };
  
  return bless $self, $class;
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
  #$self->{session}->log($Session::Verbose,"dbstring is: $dbstring");
  #$self->{session}->log($Session::Verbose,"description is: $description");

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

=head1 na_te_dros_parser

  somewhere in between

               $dbh->quote($headH->{name}).
               (exists($headH->{desc})?",".$dbh->quote($headH->{desc}):"").
               (exists($headH->{db})?",".$dbh->quote($headH->{db}):"").
               (exists($headH->{acc})?",".$dbh->quote($headH->{acc}):"").
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
  #$self->{session}->log($Session::Verbose,"dbstring is: $dbstring");
  #$self->{session}->log($Session::Verbose,"description is: $description");

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


=head1 run

  Execute the blast command. The argument is a valid sequence.

=cut

sub run
{
  my $self = shift;
  my $seq = shift;

  ($self->session->error("No fasta file saved.") and return) unless $seq->{fasta};
  my $cmd = $self->{program}." ".$self->{db}." ";
  $cmd .= $seq->{fasta}." ".$self->{options};
  $cmd .= " > ".$self->{output}." 2> ".$self->{error};

  $self->session->verbose("About to execute command: $cmd");

  &PCommon::shell($cmd);
}

=head1 DESTORY

  add to the default destructor to clean up files.

=cut
sub DESTROY
{
  my $self = shift;

  return unless $self->{clean_up};

  $self->session->log($Session::Info,"Deleting temporary blast files.");
  unlink($self->{output}) or
         $self->session->log($Session::Warn,"Trouble deleting ".$self->{output});
  unlink($self->{error}) or
         $self->session->log($Session::Warn,"Trouble deleting ".$self->{output});
}

=head1 parse_sql

  this method is deprecated. Use parse instead

=cut

sub parse_sql
{
  my $self = shift;

  return unless -s $self->{output} && -r $self->{output};

  my $dbh = $self->session()->get_db();

  open(BLST,$self->{output}) or return;
  my ($runId,$hitId,$hspId) = $self->get_next_id();

  # see if there were fatal error in this run
  if ( $self->{error} && (my $error = `grep FATAL: $self->{error}`)) {
     $error =~ s/FATAL:\s*//sg;
     $error =~ s/\n//sg;
     $self->session()->log($Session::Error,"Blast run had error(s): $error");
     return;
  }
  

  # we'll use the time stamp on the output file for the
  # time of the blast.
  my $blast_date = Files::file_date($self->{output});

  my $parser = new BPlite(\*BLST);
  $self->session->log($Session::Verbose,"Opening blast output file ".$self->{output}.".");

  # clean up the query and db a bit
  my $q_name = $parser->query;
  $q_name =~ s/\s*\(\d+ letters\)\s*$//;
  my $db_name = $parser->database;
  $db_name =~ s/$BLAST_DB//;

  my $sql = "insert into blast_run (id,seq_name,db,date) values ($runId,".
            $dbh->quote($q_name).",".$dbh->quote($db_name).
            ",".$dbh->quote($blast_date).");\n";
  my $hitCtr = 0;
  my $hitSql;
  while( my $sb = $parser->nextSbjct() ) {

    $self->session->log($Session::Verbose,"Processing hits to ".$sb->name.".");
 
    my $headH = &{$self->{subject_parser}}($sb->name);
    # prepare the sql for the hit, but we'll insert it only if there
    # is an hsp that meets our secondary standards
    $hitSql = "insert into blast_hit (id,run_id,name".
               (exists($headH->{desc})?",description":"").
               (exists($headH->{db})?",db":"").
               (exists($headH->{acc})?",accession":"").
               ") values ".
               "($hitId,$runId,".
               $dbh->quote($headH->{name}).
               (exists($headH->{desc})?",".$dbh->quote($headH->{desc}):"").
               (exists($headH->{db})?",".$dbh->quote($headH->{db}):"").
               (exists($headH->{acc})?",".$dbh->quote($headH->{acc}):"").
               ");\n";
    my $hspCtr = 0;
    # we're going to extract the hsp's then sort by score.
    my @allHsp = ();
    # here's the extract. The name of the object is overloaded, so we
    # cannot just push that; we need to recreate the object in a hash
    while( my $hsp = $sb->nextHSP() ) {
       my $tempHash;
       map { $tempHash->{$_} = $hsp->$_ }
               qw(score bits percent match positive length P qb qe sb se qa sa as qg sg);
       # watch out for underflows in postgres
       $tempHash->{P} = 0.0 if $tempHash->{P} < 1e-300;
       push @allHsp, $tempHash;
    }
    # here's the sort
    @allHsp = sort { $b->{score} <=> $a->{score} } @allHsp;
    # now go down the list, from biggest score to lowest.
    foreach my $hsp (@allHsp) {
       last if $hspCtr > $self->{max_hsp};

       my $strand = (($hsp->{qe}-$hsp->{qb})*($hsp->{se}-$hsp->{sb}) > 0)?1:-1;
       $sql .= $hitSql .
                qq(insert into blast_hsp (id,hit_id,score,bits,percent,match,
                  length,query_begin,query_end,subject_begin,subject_end,
                  query_gaps,subject_gaps,p_val,query_align,match_align,
                  subject_align,strand) values ).
                  "($hspId,$hitId,".
                  join(",",map {$dbh->quote($hsp->{$_}) }
                  qw(score bits percent match length qb qe sb se qg sg P qa as sa)).
                  ",$strand);\n";
       $hitSql = '';
       $hspId++;
       $hspCtr++;
    }
    $hitCtr++ if $hspCtr;
    $hitId++ if $hspCtr;
    last if $hitCtr > $self->{max_sub};
  }

  $self->set_ids($runId,$hitId,$hspId);

  return $sql;
}

=head1 parse

  look at the blast output and (optionally) insert the results into the db.

=cut
sub parse
{
  my $self = shift;

  return unless -s $self->{output} && -r $self->{output};

  my $dbh = $self->session()->get_db();

  open(BLST,$self->{output}) or return;


  # we'll use the time stamp on the output file for the
  # time of the blast.
  my $blast_date = Files::file_date($self->{output});

  my $parser = new BPlite(\*BLST);
  $self->session->verbose("Opening blast output file ".$self->{output}.".");

  # clean up the query and db a bit
  my $q_name = $parser->query;
  $q_name =~ s/\s*\([0-9,]+ letters\)\s*$//;
 

  # if there was an error, we cannot parse the db name
  my $db_name = $parser->database || $self->{db};
  $db_name =~ s/$BLAST_DB//;

  # prepare the blast run record.
  my $bR = new Blast_Run($self->session,
                      {seq_name => $q_name,
                       db       => $db_name || $self->{db},
                       option_id=> $self->{option_id},
                       program  => 'blastn',
                       date     => $blast_date});
  # prepare these containers for results
  my $bHitSet = new Blast_HitSet($self->session);
  my $bHspSet = new Blast_HSPSet($self->session);

  # see if there were fatal error in this run. But we'll still record the
  # run even if it failed.
  if ( $self->{error} && (my $error = `grep FATAL: $self->{error}`)) {
     $error =~ s/FATAL:\s*//sg;
     $error =~ s/\n//sg;
     $self->session->warn("Blast run had error(s): $error");
     $bR->insert unless ($_[0] eq 'noinsert');
     close(BLST);
     return ($bR,$bHitSet,$bHspSet);
  }

  my $hitCtr = 0;
  while( my $sb = $parser->nextSbjct() ) {

    $self->session->verbose("Processing hits to ".$sb->name.".");
 
    my $headH = &{$self->{subject_parser}}($sb->name);

    # prepare the hit and add it to the set
    my $bH = new Blast_Hit($self->session,
                       { run_id => $bR->ref_of('id'),
                         name   => $headH->{name} });
    $bH->description($headH->{desc}) if $headH->{desc};
    $bH->db($headH->{db}) if $headH->{db};
    $bH->accession($headH->{acc}) if $headH->{acc};
    $bHitSet->add($bH);
    
    my $hspCtr = 0;
    # we're going to extract the hsp's then sort by score.
    # since low scoring + strand hits may preceed higher scoring
    # - strand hits we cannot assume they are coming out in the
    # right order
    my @allHsp = ();

    # here's the extract. The name of the object is overloaded, so we
    # cannot just push that; we need to recreate the object in a hash
    while( my $hsp = $sb->nextHSP() ) {
       my $tempHash;
       map { $tempHash->{$_} = $hsp->$_ }
               qw(score bits percent match positive length P qb qe sb se qa sa as qg sg);
       # watch out for underflows (only in postgres?)
       $tempHash->{P} = 0.0 if $tempHash->{P} < 1e-300;
       push @allHsp, $tempHash;
    }
    # here's the sort
    @allHsp = sort { $b->{score} <=> $a->{score} } @allHsp;
    # now go down the list, from biggest score to lowest.
    foreach my $hsp (@allHsp) {
       last if $hspCtr > $self->{max_hsp};
       my $strand = (($hsp->{qe}-$hsp->{qb})*($hsp->{se}-$hsp->{sb}) > 0)?1:-1;
       my $bHsp = new Blast_HSP($self->session,
                                 { hit_id => $bH->ref_of('id') } );
       $bHsp->score($hsp->{score});
       $bHsp->bits($hsp->{bits});
       $bHsp->percent($hsp->{percent});
       $bHsp->match($hsp->{match});
       $bHsp->length($hsp->{length});
       $bHsp->query_begin($hsp->{qb});
       $bHsp->query_end($hsp->{qe});
       $bHsp->subject_begin($hsp->{sb});
       $bHsp->subject_end($hsp->{se});
       $bHsp->query_gaps($hsp->{qg});
       $bHsp->subject_gaps($hsp->{sg});
       $bHsp->p_val($hsp->{P});
       $bHsp->query_align($hsp->{qa});
       $bHsp->match_align($hsp->{as});
       $bHsp->subject_align($hsp->{sa});
       $bHsp->strand($strand);
       $hspCtr++;

       # add it to the hsp.
       $bHspSet->add($bHsp);
    }
    $hitCtr++ if $hspCtr;
    last if $hitCtr > $self->{max_sub};
  }

  unless ($_[0] eq 'noinsert') {
    $bR->insert;
    $bHitSet->insert;
    $bHspSet->insert;
  }

  close(BLST);
  return ($bR,$bHitSet,$bHspSet);
}

sub session      { shift->{session}; }
sub get_output_file  { shift->{output}; }
sub get_error_file   { shift->{error}; }

    
sub get_next_id
{
  my $self = shift;
  
  return ((new Blast_Run($self->session))->get_next_id,
          (new Blast_Hit($self->session))->get_next_id,
          (new Blast_HSP($self->session))->get_next_id);
}

sub set_ids
{
  my $self = shift;

  my $a = new Blast_Run($self->session);
  $a->set_id(shift);
  $a = new Blast_Hit($self->session);
  $a->set_id(shift);
  $a = new Blast_HSP($self->session);
  $a->set_id(shift);
}
  
1;

