#!/usr/local/bin/perl -I ../modules

use Session;
use Blast_HSP;
use Blast_Hit;
use Blast_Run;
use Seq_Alignment;
use Seq;


my $session = new Session();

my $match_str = '\|'x15;

my $ndel = 0;
foreach $i (2000000..2001000) {

   my $b = new Blast_HSP($session,{-id=>$i})->select_if_exists;
   next unless $b->hit_id;

   $session->log($Session::Info,"Looking at hit $i with score ".$b->score);
   
   if ($b->match_align =~ /$match_str/ ) {
      $session->log($Session::Info,"This hit makes the score threshold.");
      next;
   }

   my $h = new Blast_Hit($session,{-id=>$b->hit_id})->select_if_exists;

   unless ($h->id) {
      $session->log($Session::Warn,"No parent for HSP ".$b->id);
      next;
   }

   my $r = new Blast_Run($session,{-id=>$h->run_id})->select_if_exists;

   unless ($r->id) {
      $session->log($Session::Warn,"No parent for hit ".$h->id);
      next;
   }

   if ($r->db ne 'release3_genomic') {
     $session->log($Session::Info,"Wrong db.");
   }

   my $s = new Seq($session,{-seq_name=>$r->seq_name})->select_if_exists;

   unless ($s->sequence) {
      $session->log($Session::Warn,"No sequence for seq ".$s->seq_name);
      next;
   }

   if (length($s->sequence) < $b->score) {
      $session->log($Session::Info,"This hit makes the ratio threshold.");
      next;
   }

   my $a = new Seq_Alignment($session,{-hsp_id=>$b->id});
   if ($a->db_exists ) {
      $session->log($Session::Info,"This hit was made into an alignment.");
      next;
   }

   my $hit = new Blast_HSP($session,{-hit_id=>$b->hit_id});
   my $hitCount = $hit->db_count;
   $session->log($Session::Info,"Hit count for this is $hitCount.");

   if ($hitCount == 1) {
      $hit->select;
      $hit->delete;
   } else {
      $
      
   $nDel++;
}

   
$session->log($Session::Info,"Delete $nDel HSP records.");
$session->exit;

