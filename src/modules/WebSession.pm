=head1 NAME

   WebSession.pm

   An object for tracking web logins

=head1 USAGE

   use WebSession;
   $webSession = new webSession($db,$login)

=head1 REQUIRED PARAMETERS

   $db a database handle
   $login a validated login name


=cut

package WebSession;

use strict;
no strict 'refs';

use Pelement;
use PCommon;
use PelementDBI;

use Digest::MD5;

# global static definitions
BEGIN {
}


=head1 PUBLIC METHODS

=head2  new 

  Create a collection that will map to the the Websession table

=cut
sub new 
{
  my $class = shift;
  my $db = shift;
  my $login = shift || '';

  return unless $db;

  # we'll use a combination of the username and the timestamp to
  # create the initial hash into the websession table. In the
  # off chance that this is already there, we'll allow a few
  # retries.

  my ($timestamp,$webId);
  
  # if we've gotten a username, create an entry
  if( $login) {
     my $nTries = 0;
     do {
        $timestamp = time();
        $webId = md5sum($login.$timestamp);
        my $is_there = $db->select(qq(select count(*) from websession where
                                   websessionId = '$webId') );
        last unless $is_there;
        sleep(1);
        $nTries++;
     } while ($nTries < 15);
  
     $db->do(qq(insert into websession (webid,login,timestamp) values
                                   ('$webId','$login','$timestamp')));
  }
  
  my $self = {db        => $db,
              login     => $login,
              webId     => $webId,
              timestamp => $timestamp };

  bless $self, $class;
  return $self;

}

sub db 
{
  my $self = shift;
  (@_)?return $self->{db} = shift:return $self->{db};
}

sub login
{
  my $self = shift;
  (@_)?return $self->{login} = shift:return $self->{login};
}

sub timestamp
{
  my $self = shift;
  (@_)?return $self->{timestamp} = shift:return $self->{timestamp};
}

sub webId
{
  my $self = shift;
  (@_)?return $self->{webId} = shift:return $self->{webId};
}


=head1 retrieve

   Returns a websession object if the web session id is in the db

=cut

sub retrive
{
  
  my $self = shift || return;
  my $sessionId = shift || return;


  my @entry = ();
  $self->db->select(
       qq(select login,timestamp from websession where webid='$sessionId'),
       \@entry);
  return unless @entry;

  $self->login($entry[0]);
  $self->timestamp($entry[1]);
}

=head1 delete

   Deletes the websession object with a specified id

=cut

sub delete
{
  my $self = shift || return;
  my $sessionId = shift || $self->webId || return;

  $self->db->do(qq(delete from websession where webid='$sessionId'));

  return;
}

=head1 update

  Refreshes the timestamp to the current time value

=cut

sub update
{
  my $self = shift || return;
  my $sessionId = shift || $self->webId || return;

  my $timestamp = time();
  $self->db->do(qq(update websession set timestamp=$timestamp where webid='$sessionId'));
  return $timestamp;
}

1;

