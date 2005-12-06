#!/usr/local/bin/perl -w -I../modules

=head Name

  transferTables.pl a temporary utility for copying tables from
  epflow to pelement

=head1 usage

  transferTables.pl [-verbose | -noverbose]

=cut


use Getopt::Long;
use Session;
use Batch;
use Sample;
use Strain;
use Digestion;
use Ligation;
use IPCR;
use Gel;

use strict;

my $session = new Session();

my $nIpcrInsert = 0;
my $nGelInsert = 0;
my $painfullyVerbose = 0;
my $test = 0;

GetOptions( "test!"    => \$test,
               );

my $epflowDB = DBI->connect("dbi:Informix:epflow") or
               die "Trouble talking to informix.";


$session->die("This is defunct.");


$session->log($Session::Info,"Test mode: no undating done.") if $test;

$session->log($Session::Info,"Retrieving batch_register table.");
my $st = $epflowDB->prepare(qq(select batch_num,description,user_login,prep_date
                               from batch_register order by batch_num));

$st->execute() or die "Trouble executing SQL.";

my $row;
while ($row = $st->fetchrow_arrayref) {
   trimWhite($row);
   my ($id,$description,$user,$date) = @$row;
   my $batch = new Batch($session,{-id=>$id});
   if ($batch->db_exists) {
     $session->log($Session::Info,"Record for ".$batch->id." exists.") if $painfullyVerbose;
     next;
   } else {
     $session->verbose("Creating record for batch ".$batch->id.".");
   }

   $batch->id($id);
   $batch->description($description) if $description;
   $batch->user_login($user);
   $batch->batch_date($date);
   $batch->insert;
}

$session->log($Session::Info,"Retrieving sample table.");
$st = $epflowDB->prepare(qq(select batch_id,batch_num,batch_pos,strain_name
                               from batch order by batch_id));

$st->execute() or die "Trouble executing SQL.";

while ($row = $st->fetchrow_arrayref) {
   trimWhite($row);
   my ($id,$num,$pos,$strain) = @$row;
   my $sample = new Sample($session,{-batch_id=>$num,-well=>$pos});
   if ($sample->db_exists) {
     $session->log($Session::Info,"Record for ".$sample->batch_id." exists.")
                                                       if $painfullyVerbose;
     next;
   } else {
     $session->verbose("Creating sample record for batch ".
                                    $sample->batch_id.".") if $strain;
   }
   # don't try to stick in empty strains.
   next unless $strain;
   # make sure we have this strain already
   my $str = new Strain($session,{-strain_name=>$strain});
   unless ($str->db_exists) {
      $str->status('new');
      $str->collection(substr($strain,0,2));
      $str->registry_date('today');
      $str->insert;
   }
   $sample->strain_name($strain);
   $sample->insert;
}

$session->log($Session::Info,"Retrieving digestion table.");
$st = $epflowDB->prepare(qq(select digestion_id,batch_num,enzyme,enzyme2,
                            digestion_date,user_login
                            from digestions order by batch_num));

$st->execute() or die "Trouble executing SQL.";

while ($row = $st->fetchrow_arrayref) {
   trimWhite($row);
   my ($id,$num,$e1,$e2,$date,$user) = @$row;
   my $sample = new Digestion($session,{-name=>$id});
   if ($sample->db_exists) {
     $session->log($Session::Info,"Record for ".$sample->name." exists.") if $painfullyVerbose;
     next;
   } else {
     $session->verbose("Creating record for ".$sample->name.".");
   }
   $sample->batch_id($num);
   $sample->enzyme1($e1);
   $sample->enzyme2($e2) if $e2;
   $sample->user_login($user);
   $sample->digestion_date($date);
   $sample->insert;
}

$session->log($Session::Info,"Retrieving ligation table.");
$st = $epflowDB->prepare(qq(select ligation_id,digestion_id,ligation_date,user_login
                               from ligations order by ligation_id));

$st->execute() or die "Trouble executing SQL.";

while ($row = $st->fetchrow_arrayref) {
   trimWhite($row);
   my ($id,$dig,$date,$user) = @$row;
   my $sample = new Ligation($session,{-name=>$id});
   if ($sample->db_exists) {
     $session->log($Session::Info,"Record for ".$sample->name." exists.") if $painfullyVerbose;
     next;
   } else {
     $session->verbose("Creating record for ".$sample->name.".");
   }
   $sample->digestion_name($dig);
   $sample->user_login($user);
   $sample->insert;
}

$session->log($Session::Info,"Retrieving ipcr table.");
$st = $epflowDB->prepare(qq(select ipcr_id,ligation_id,primer1,
                              primer2,end_type,pcr_date,user_login
                              from ipcr)) or
         die "Trouble talking to informix.";

$st->execute() or die "Trouble executing SQL.";

while ($row = $st->fetchrow_arrayref) {
   trimWhite($row);
   my ($ipcr_id,$ligation_id,$primer1,$primer2,$end_type,$pcr_date,$user_login) = @$row;
   foreach my $var ($ipcr_id,$ligation_id,$primer1,$primer2,$end_type,$pcr_date,$user_login) {
      next unless defined $var;
      $var =~ s/^\s*(\S*)/$1/;
      $var =~ s/(\S*)\s*$/$1/;
   }
   my $ipcr = new IPCR($session,{name=>$ipcr_id});
   if ($ipcr->db_exists) {
     $session->log($Session::Info,"Record for ".$ipcr->name." exists.") if $painfullyVerbose;
     next;
   } else {
     $session->verbose("Creating record for ".$ipcr->name.".");
   }
   $ipcr->name($ipcr_id);
   $ipcr->ligation_name($ligation_id);
   $ipcr->primer1($primer1);
   $ipcr->primer2($primer2);
   $ipcr->end_type($end_type);
   $ipcr->ipcr_date($pcr_date);
   $ipcr->user_login($user_login);
   $ipcr->insert unless $test;
   $nIpcrInsert++;
}


$st = $epflowDB->prepare(qq(select gel_id,gel_name,ipcr_id,
                               part_num,gel_date,user_login,seq_primer
			       from gel_registries)) or
         die "Trouble talking to informix.";

$st->execute() or die "Trouble executing SQL.";

while ($row = $st->fetchrow_arrayref) {
   trimWhite($row);
   my ($gel_id,$gel_name,$ipcr_id,$part_num,$gel_date,$user_login,$seq_primer) = @$row;
   foreach my $var ($gel_id,$gel_name,$ipcr_id,$part_num,$gel_date,$user_login,$seq_primer) {
      next unless defined $var;
      $var =~ s/^\s*(\S*)/$1/;
      $var =~ s/(\S*)\s*$/$1/;
   }
   my $gel = new Gel($session,{name=>$gel_name});
   if ($gel->db_exists) {
     $session->log($Session::Info,"Record for ".$gel->name." exists.") if $painfullyVerbose;
     next;
   } else {
     $session->verbose("Creating record for ".$gel->name.".");
   }
   $gel->name($gel_name);
   $gel->ipcr_name($ipcr_id);
   $gel->gel_date($gel_date);
   $gel->user_login($user_login);
   $gel->seq_primer($seq_primer);
   $gel->insert unless $test;
   $nGelInsert++;
}

$epflowDB->disconnect();


$session->log($Session::Info,"Updated $nIpcrInsert ipcr records and $nGelInsert gel records.");
$session->exit;
exit;

sub trimWhite { my $arg = shift; return unless @$arg; map { !$_ || s/\s+$// } @$arg }
