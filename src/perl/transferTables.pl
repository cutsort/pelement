#!/usr/local/bin/perl -w -I../modules

=head Name

  transferTables.pl a temporary utility for copying tables from
  epflow to pelement

=head1 usage

  transferTables.pl [-verbose | -noverbose]

  default behavior is -verbose

=cut


use Getopt::Long;
use Session;
use IPCR;
use Gel;


my $session = new Session();

$nIpcrInsert = 0;
$nGelInsert = 0;
$verbose = 1;
$test = 0;

GetOptions("verbose!" => \$verbose,
           "test!"    => \$test,
);

my $epflowDB = DBI->connect("dbi:Informix:epflow") or
               die "Trouble talking to informix.";

$session->log($Session::Info,"Test mode: no undating done.") if $test;

my $st = $epflowDB->prepare(qq(select ipcr_id,ligation_id,primer1,
                              primer2,end_type,pcr_date,user_login
                              from ipcr)) or
         die "Trouble talking to informix.";

$st->execute() or die "Trouble executing SQL.";

while ($row = $st->fetchrow_arrayref) {
   my ($ipcr_id,$ligation_id,$primer1,$primer2,$end_type,$pcr_date,$user_login) = @$row;
   foreach my $var ($ipcr_id,$ligation_id,$primer1,$primer2,$end_type,$pcr_date,$user_login) {
      next unless defined $var;
      $var =~ s/^\s*(\S*)/$1/;
      $var =~ s/(\S*)\s*$/$1/;
   }
   my $ipcr = new IPCR($session,{ipcr_id=>$ipcr_id});
   if ($ipcr->db_exists) {
     $session->log($Session::Info,"Record for ".$ipcr->ipcr_id." exists.") if $verbose;
     next;
   } else {
     $session->log($Session::Info,"Creating record for ".$ipcr->ipcr_id." exists.") if $verbose;
   }
   $ipcr->ipcr_id($ipcr_id);
   $ipcr->ligation_id($ligation_id);
   $ipcr->primer1($primer1);
   $ipcr->primer2($primer2);
   $ipcr->end_type($end_type);
   $ipcr->pcr_date($pcr_date);
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
   my ($gel_id,$gel_name,$ipcr_id,$part_num,$gel_date,$user_login,$seq_primer) = @$row;
   foreach my $var ($gel_id,$gel_name,$ipcr_id,$part_num,$gel_date,$user_login,$seq_primer) {
      next unless defined $var;
      $var =~ s/^\s*(\S*)/$1/;
      $var =~ s/(\S*)\s*$/$1/;
   }
   my $gel = new Gel($session,{name=>$gel_name});
   if ($gel->db_exists) {
     $session->log($Session::Info,"Record for ".$gel->name." exists.") if $verbose;
     next;
   } else {
     $session->log($Session::Info,"Creating record for ".$gel->name." exists.") if $verbose;
   }
   $gel->name($gel_name);
   $gel->ipcr_id($ipcr_id);
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

