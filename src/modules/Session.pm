=head1 NAME

   Session.pm

   A module for maintaining persistent information across
   a processing step

=head1 USAGE

   use Session;
   $session = new Session([options])

=head1 OPTIONS

   -useDb=>0  Do not open the database. Default is to open the db
   -log_level=>N Set level of logging. symbolic values are:
                  $Session::NoLog (nothing is logged),
                  $Session::Error (unexpected and uncoverable messages only),
                  $Session::Warn (unexpected but recoverable messages only),
                  $Session::Info (routine processing),
                  $Session::Verbose (more messages)
                  $Session::SQL  (even more; including SQL parsing)

=cut

package Session;

use strict;
use File::Basename;
use Getopt::Long qw(:config pass_through);
no strict 'refs';

use Pelement;
use PCommon;
use PelementDBI;
use Files;


# global static definitions
BEGIN {
   $Session::NoLog    = 0;
   $Session::Error    = 1;
   $Session::Warn     = 2;
   $Session::Info     = 3;
   $Session::Verbose  = 4;
   $Session::SQL      = 5;
}


=head1 PUBLIC METHODS

=head2  new

  Create a session.

=cut
sub new
{
  my $class = shift;

  # things to declare
  my $dbh;

  # we'll look for a hash of optional arguments. these maybe overriden
  # by things that were passed commandline
  my $args = shift;

  # default settings for arguments
  my $useDb = defined(PCommon::parseArgs($args,"useDb"))?
                      PCommon::parseArgs($args,"useDb"):1;

  # we'll assign a (hopefully) unique identifier to each session. it will
  # consist of the time since the epoch followed by the process id.
  my $id = time() .".". $$;

  # and a record of who opened up.
  my $caller = (caller())[1] || "UnknownCaller";
  # but trim off some annoying path items. Everything up to a /.
  $caller = (fileparse($caller,'\.pl'))[0];

  my $log_level = defined(PCommon::parseArgs($args,"log_level"))?
                          PCommon::parseArgs($args,"log_level"):$Session::Info;


  # command line options. passed through if not understood
  my ($verbose,$quiet);
  GetOptions( "verbose!" => \$verbose,
              "quiet!"   => \$quiet,
              "db!"      => \$useDb, );

  Getopt::Long::Configure("no_pass_through");

  $log_level = $Session::NoLog if $quiet;
  $log_level = $Session::Verbose if $verbose;


  my $self = {"exit_code"     => [],
              "error_code"    => {},
              "caller"        => $caller,
              "log_level"     => $log_level,
              "log_file"      => *LOG,
              "interactive"   => (-t STDIN),
              "id"            => $id,
              "col_hash"      => {},
             };

  if ($self->{log_level} ) {
     open(LOG,">$PELEMENT_LOG/$caller.$$")
                   or die "Serious trouble: cannot open log file: $!";
     $self->{log_file_name} = "$PELEMENT_LOG/$caller.$$";
  } else {
     open(LOG,">/dev/null");
     $self->{log_file_name} = "/dev/null";
  }


  my $blessed_self =  bless $self, $class;

  if ( $useDb ) {
    $dbh = new PelementDBI($self,"dbi:$PELEMENT_DB_DBI:$PELEMENT_DB_CONNECT");
    $self->{db} = $dbh;
    $self->{db_tx} = 0;
  }

  if (@::ARGV) {
    $self->log($Session::Info,"$caller ".join(" ",@::ARGV)." started.");
  } else {
    $self->log($Session::Info,"$caller started.");
  }


  return $blessed_self;

}

=head2 db_begin db_commit db_rollback

   Start or stop a db transaction. we're also deferring constraints
   within the transaction.

=cut

sub db_begin
{
  my $self = shift;
  $self->warn("No db connection") and return unless $self->{db};
  $self->warn("Already in transaction") and return if $self->{db_tx};

  eval { $self->{db}->{dbh}->{AutoCommit} = 0 };
  if ($@) {
     $self->die("Some trouble attempting to start a transaction:".
                  $self->{db}->errstr);
  }
  $self->{db}->do('set constraints all deferred');
  $self->{db_tx} = time;
  $self->verbose("Beginning a transaction");

}
sub db_commit
{
  my $self = shift;
  $self->warn("No db connection") and return unless $self->{db};
  $self->warn("Not in a transaction") and return unless $self->{db_tx};

  $self->{db_tx} = 0;
  $self->{db}->commit;
  eval { $self->{db}->{dbh}->{AutoCommit} = 1 };
  if ($@) {
     $self->die("Some trouble attempting to stop a transaction:".
                  $self->{db}->errstr);
  }
  $self->verbose("Committing a transaction");
}
sub db_rollback
{
  my $self = shift;
  $self->warn("No db connection") and return unless $self->{db};
  $self->warn("Not in a transaction") and return unless $self->{db_tx};

  $self->{db_tx} = 0;
  $self->{db}->rollback;

  eval { $self->{db}->{dbh}->{AutoCommit} = 1 };
  if ($@) {
     $self->die("Some trouble attempting to stop a transaction:".
                  $self->{db}->errstr);
  }
  $self->verbose("Rolling back a transaction");
}

=head2 exit

   Close the current session. This does not terminate the script. This
   should be safe if it gets called repeatedly but ineffectual after
   the first.

=cut

sub exit
{

  my $self = shift;
  # first we execute the stack of exit routines
  # make this work.
  foreach my $block (reverse @{$self->{exit_code}}) {
    $self->verbose("Executing block of exit code.");
    &$block;
  }

  # check to see if we're in a transaction. Uncommitted changes are
  # rolled back.
  if ($self->{db} && $self->{db_tx} ) {
    $self->warn("Rolling back uncommited changes.");
    $self->db_rollback;
  }

  if ( $self->{log_file} ) {
     # close the log file
     $self->log($Session::Info,"Processing ".$self->{caller}." ended.");
     close($self->{log_file});
     $self->{log_file} = '';

     unless ( $self->{log_file_name} eq "/dev/null" ) {

        my $bigLogFile = "$PELEMENT_LOG/".$self->{caller}.".log";

        # now, append the log file to the master log. We should probably
        # implement a better file locking mechanism to ensure we are not
        # appending from two process, but until then (read that: never) we'll
        # make sure the master log has been stagnant for 3 seconds.
        if ( -e $bigLogFile ) {

            # we try this multiple times, but then just say the hell with it
            # if we are waiting too long.
            my $nTries = 0;
            while( time() - Files::file_timestamp($bigLogFile) < 3  &&
                    $nTries < 20 )   {
               $nTries++;
               sleep(2);
            }
         } else {
            Files::touch($bigLogFile) or warn "Cannot create log file: $!";
         }
         if ( Files::append($self->{log_file_name},$bigLogFile) ) {
            Files::delete($self->{log_file_name}) or
                                   warn "Cannot delete log file: $!";
         } else {
            warn "Cannot append to log file $bigLogFile: $!";
         }

     }
   }

   unless ($self->{db}) {
      # finally close the db handle
      $self->db()->disconnect() if $self->{db};
      $self->{db} = '';
   }

   return 1;
}


=head2 log_level

   Gets or Sets the value of the amount log information processed.
   Values are:
   $Session::NoLog    nothing is printed, ever
   $Session::Error    error messages only are printed,
   $Session::Warn     unexpected, but recoverable, situations are reported
   $Session::Info     normal processing message are printed,
   $Session::Verbose  copious verbiage
   $Session::SQL      copious and SQL

   When a message is logged, a optional level level (default is $Info) is
   passed. If the current log_level is less than or equal to the value of
   log_level the message is printed.

=cut

sub log_level
{
  my $self = shift;
  if (@_) {
    my $level = shift @_;

    if (grep(/^$level$/,($Session::NoLog,$Session::Error,$Session::Info,$Session::Verbose,$Session::SQL)) ) {
      $self->{log_level} = $level;
      $self->log($Session::Info,"log level set to $level.");
    } else {
      $self->error("Invalid Parameter","value for log level: $level not valid.");
    }
    return;
  } else {
    return $self->{log_level};
  }
}

=head2 log

  Prints the current message if the level of this message is greater
  than or equal to the current logging  level

=cut
sub log
{
  my $self = shift;
  my $level = shift;
  my $message = join('',@_);

  print {$self->{log_file}} &time_value(),"\t$message\n"
                     if $level <= $self->log_level;
  print "$message\n" if $level <= $self->log_level && $self->{interactive};

  return 1;
}

=head2 warn, info, debug, verbose

  Aliases for log at the right level

=cut
sub warn { return shift->log($Session::Warn,@_) }
sub info { return shift->log($Session::Info,@_) }
sub debug { return shift->log($Session::Verbose,@_) }
sub verbose { return shift->log($Session::Verbose,@_) }

=head2 get_db

   Returns the database handle
   db is a synonym for this routine.

=cut
sub get_db { return shift->{db}; }
sub db { return shift->{db}; }

=head2 get_id

   Returns the identifier for this session. This is useful when
   some unique tag is needed
   id is a synonym for this routine.

=cut

sub get_id { return shift->{id}; }
sub id {return shift->{id}; }

=head2 at_exit

  Pushes a block of code onto a stack which is executed when closing
  the session. These are executed from the last registered block to the
  first registered block

=cut
sub at_exit
{
  my $self = shift;
  push @{$self->{exit_code}} , shift;
}

=head2 on_error

  Installs various error handlers into the current session. This
  requires 2 arguments: a tag for the error class, and block of code
  to run.

  I'm having doubts about this implementation right now; it relies on
  passing a > 1 element list to error and using the first element as
  a key to the error handler.

=cut
sub on_error
{
  my $self = shift;
  my ($tag,$code) = @_;
  ${$self->{error}}->{$tag} = $code;
}

=head2 error

   Uses the installed error handler, or the default of logging and dying

=cut
sub error
{
  my $self = shift;
  my $message = join("",@_);
  my $tag = $_[0];

  (&{$self->{error}->{$tag}} and return) if exists $self->{error}->{$tag};

  $self->log($Session::Error,$message);
  $self->exit();
}

=head2 die

   An error call with process exit

=cut
sub die
{
  my $self = shift;
  $self->error(@_);
  CORE::exit(2);
}

sub DESTROY
{
  my $self = shift;
  $self->exit;
}

sub AUTOLOAD
{
  my $self = shift;
  CORE::die "$self is not an object." unless ref($self);

  my $name = $Session::AUTOLOAD;

  $name =~ s/.*://;
  my @packageClass;

  if ($name =~ /^([A-Z].*)Set/ ) {
    push @packageClass, ($1,'DbObject',$name,'DbObjectSet');
  } elsif ($name =~ /^([A-Z].*)Cursor/ ) {
    push @packageClass, ($1,'DbObject',$name,'DbObjectCursor');
  } elsif ($name =~ /^([A-Z].*)/ ) {
    push @packageClass, ($name,'DbObject');
  }

  $self->die("No such method $name.") unless @packageClass;

  my $loaded = 0;
  foreach my $dir (@INC) {
    if (-e $dir.'/'.$name.'.pm') {
       require $name.'.pm';
       $loaded = 1;
       last;
    }
  }

  # fallback
  unless ($loaded) {
    while (@packageClass) {
      my ($a,$b) = splice(@packageClass,0,2);
      eval "package $a; use $b;";
    }
  }

  my $thingy = $name->new($self,@_);
  return $thingy;

}

1;
