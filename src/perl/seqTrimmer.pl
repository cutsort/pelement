#!/usr/local/bin/perl -I../modules

=head1 NAME

  seqTrimmer.pl process database record of phred sequence and 
  quality and trim by quality and vector.

=head1 USAGE

  seqTrimmer.pl <-gel name> | <-gel_id number> |  <-lane name> | <lane_id number>

  One of gel name, gel id, lane (file) name or lane id must be specified.

=cut

use Pelement;
use PCommon;
use Processing;
use Session;
use Gel;
use Lane;
use LaneSet;
use Files;
use Strain;
use Digestion;
use Enzyme;
use Vector;
use Trimming_Protocol;
use Collection_Protocol;
use PelementDBI;
use Phred_Seq;
use Phred_Qual;

# George's sim4-er
use GH::Sim4;

use File::Basename;
use Getopt::Long;
use strict;


my $session = new Session();

# option processing. 
# we specify what we are processing by the switch of either
#         -gel Name         process a gel by name
#         -gel_id Number    process a gel by internal db number id
#         -lane Name        process a lane by filename
#         -lane_id Number   process a lane by internal db number id

my ($gel_name,$gel_id,$lane_name,$lane_id);

GetOptions('gel=s'      => \$gel_name,
           'gel_id=i'   => \$gel_id,
           'lane=s'     => \$lane_name,
           'lane_id=i'  => \$lane_id,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.

my ($gel,@lanes);

if ($gel_name || $gel_id) {
   unless ($gel_id) {
      $gel = new Gel($session,{-name=>$gel_name})->select_if_exists;
      $session->error("No Gel","Cannot find gel with name $gel_name.")
                                                       unless $gel->id;
      $gel_id = $gel->id;
   }
   my $laneSet = new LaneSet($session,{-gel_id=>$gel_id})->select;
   $session->error("No Lane","Cannot find lanes with gel id $gel.")
                                                       unless $laneSet;
   @lanes = $laneSet->as_list;
} elsif ( $lane_name ) {
   @lanes = (new Lane($session,{-name=>$lane_name})->select_if_exists);
} elsif ( $lane_id ) {
   @lanes = (new Lane($session,{-id=>$lane_id})->select_if_exists);
} else {
   $session->error("No arg","No options specified for trimming.");
   exit(0);
}

$session->log($Session::Info,"There are ".scalar(@lanes)." lanes to process");

foreach my $lane (@lanes) {

   $session->log($Session::Info,"Processing lane ".$lane->seq_name);

   # be certain there is enough info for processing the lane
   ($session->error("end_sequenced not specified for lane ".$lane->id) and
                                          exit(1)) unless $lane->end_sequenced;
   ($session->error("seq_name not specified for lane ".$lane->id) and exit(1))
                                                  unless $lane->seq_name;
   ($session->error("gel_id not specified for lane ".$lane->id) and exit(1))
                                                  unless $lane->gel_id;


   $gel = new Gel($session,{-id=>$lane->gel_id})->select
                                             unless $gel && $gel->id;
 
   # determine the digestion identifer from which this comes.
   my $digestion = new Digestion($session,
                    {-name=>&Processing::digestion_id($gel->ipcr_name)}
                                 )->select;

   unless ($digestion && $digestion->enzyme1) {
      $session->error("Cannot determine digestion enzyme for ".
                                                 $lane->seq_name);
      exit(1);
   }

   # find the associated phred called sequences.
   my $phred_seq = new Phred_Seq($session,
                         {-lane_id=>$lane->id})->select_if_exists;

   ($session->log($Session::Warn,"No sequence for lane $lane_id.") and next )
                                                          unless $phred_seq;
   my $phred_qual = new Phred_Qual($session,
                         {-phred_seq_id=>$phred_seq->id})->select_if_exists;

   ($session->log($Session::Warn,
                    "No quality for lane $lane->id.") and next )
                                                   unless $phred_qual;
      
   my $strain = new Strain($session,{-strain_name=>$lane->seq_name})->select;
   unless ($strain && $strain->collection) {
      $session->error("No collection identifier for ".$lane->seq_name);
      exit(1);
   }

   my $c_p = new Collection_Protocol($session,
                       {-collection=>$strain->collection,
                        -like=>{end_sequenced=>'%'.$lane->end_sequenced.'%'}}
                                                     )->select;
   unless ($c_p->protocol_id) {
      $session->error("Cannot determine trimming protocol for ".
                                                          $strain->collection);
      exit(1);
   }

   my $t_p = new Trimming_Protocol($session,{-id=>$c_p->protocol_id})->select;
   if ($t_p->id) {
      $session->log($Session::Info,"Using trimming protocol ".
                                                          $t_p->protocol_name)
                                                       if $t_p->protocol_name;
   } else {
      $session->error("Cannot determine trimming protocol for ".
                                                       $strain->collection);
      exit(1);
   }
   
   my $vector = new Vector($session,{-id=>$t_p->vector_id})->select;

   my $vStart = vectorTrim($phred_seq->seq,$vector->sequence);
   my $foundVec = 0;
   if ( defined ($vStart) ) {
      $vStart += $t_p->vector_offset;
      $session->log($Session::Info,"Sequence starts after vector at $vStart.");
   } else {
      $session->log($Session::Info,"Cannot find vector for ".$lane->seq_name);
      $vStart = 0;
   }

   my $enz = new Enzyme($session,{-enzyme_name=>$digestion->enzyme1})->select;

   unless ($enz && $enz->restriction_seq) {
      $session->error("Cannot determine restriction sequence for ".
                                                       $enz->enzyme_name);
      exit(1);
   }

   (my $cutSeq = uc($enz->restriction_seq)) =~ s/[^ACGT]//g;

   my $vEnd = siteTrim(substr($phred_seq->seq,$vStart),$cutSeq);
   
   if ($vEnd) {
      $vEnd += $vStart;
      $session->log($Session::Info,
                 "Sequence ends before restriction site at $vEnd.");
   } else {
      $session->log($Session::Info,"No restriction site found.");
   }


   # quality trim according to a set of rules determined by a
   # threshold and the number of bp's below the threshold.
   my ($qStart,$qEnd);
   foreach my $ruleSet ( {-thresh=>20,-num=> 5,-start=>$vStart},
                         {-thresh=>15,-num=>10,-start=>$vStart} ) {
      qualityTrim($phred_qual->qual,$ruleSet);
      # if we cannot locate the end, none of the quality is high enuf
      if (!exists($ruleSet->{-end}) ) {
         $session->log($Session::Info,"Cannot quality trim: quality too low.");
      } else {
         $session->log($Session::Info,"From a rule set, quality limits are ".
                                $ruleSet->{-start}." and ".$ruleSet->{-end});
         $qStart = $ruleSet->{-start}
                               if (!$qStart || $qStart < $ruleSet->{-start});
         $qEnd = $ruleSet->{-end}    if (!$qEnd || $qEnd > $ruleSet->{-end});
      }
   }

   $session->log($Session::Info,"Final quality limits are $qStart, $qEnd.");

   # update
   $phred_seq->v_trim_start($vStart) if $vStart;
   $phred_seq->v_trim_end($vEnd) if $vEnd;
   $phred_seq->q_trim_start($qStart) if $qStart;
   $phred_seq->q_trim_end($qEnd) if $qEnd;
   $phred_seq->update;
   

}

$session->exit();

exit(0);

sub qualityTrim
{
   my ($qual,$rule) = @_;

   # get rid of spurious spaces
   $qual =~ s/^\s+//;

   # split into individual quality scores.
   my @q = split(/\s+/,$qual);

   my $loCtr = 0;
 
   # start from the bottom and work up to get
   # quality cutoff
   $rule->{-start} = 0 unless exists $rule->{-start};

   foreach my $i ($rule->{-start}..$#q) {
      if ( $q[$i] < $rule->{-thresh} ) { 
         $loCtr++;
      } else {
         $loCtr = 0;
      }

      # $i-$loCtr is the index to the last
      # quality score above the threshold
      # we'll add 1 to make it an 'interbase' coordinate
      # but we have to make sure it doesn't point back
      # to before we started looking.
      # we'll allow cases where the base before the start is above
      # threshold, but the first base after we look is below threshold
      $rule->{-end} = $i - $loCtr + 1
                    unless ($i-$loCtr     < $rule->{-start}-1 ||
                            $i-$loCtr     < 0                 ||
                            $q[$i-$loCtr] < $rule->{-thresh});

      last if $loCtr > $rule->{-num};
   }

   return unless exists $rule->{-end};

   $loCtr = 0;
   foreach my $i (reverse(0..($rule->{-end}))) {
      if ($q[$i] < $rule->{-thresh} ) {
         $loCtr++;
      } else {
         $loCtr = 0;
      }
      $rule->{-start} = $i + $loCtr;

      last if $loCtr > $rule->{-num};
   }

}

sub vectorTrim
{
   my ($s,$v) = @_;
   my $r = GH::Sim4::sim4(uc($v),uc($s));

   return unless $r->{exons}[0];
   return $r->{exons}[0]{to2};
}

sub siteTrim
{
   my ($s,$v) = (uc($_[0]),uc($_[1]));
   return unless $s =~ /$v/;
   return length($`)+length($&);
}
