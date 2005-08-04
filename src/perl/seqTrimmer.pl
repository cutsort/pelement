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
#         -enzyme Name      specify the restriction enzyme used (mainly for
#                           offline processing of individual lanes)
#         -vector <seq>     specify a vector-insert junction (for offline
#                           processing of individual lanes)
#         -insert Number    specify an offset location of the insert relative
#                           to the vector-insert junction (for offline
#                           processing)
#         -test             testmode only; no updates
#         -redo             reprocess lanes where values have been set
#                           this will erase manually set values
#                           If ANY value is set, nothing will be changed

my ($gel_name,$gel_id,$lane_name,@lane_id,$enzyme,$vector_junc,$offset,$redo);
my $test = 0;

GetOptions('gel=s'      => \$gel_name,
           'gel_id=i'   => \$gel_id,
           'lane=s'     => \$lane_name,
           'lane_id=i@' => \@lane_id,
           'enzyme=s'   => \$enzyme,
           'test!'      => \$test,
           'vector=s'   => \$vector_junc,
           'insert=i'   => \$offset,
           'redo!'      => \$redo,
          );

# processing hierarchy. In case multiple things are specified, we have to
# decide what to process. (Or flag it as an error? No. Always deliver something)
# gels by name are first, then by gel_id, then by lane name, then by lane_id.

my ($gel,@lanes);

if ($gel_name || $gel_id) {
   unless ($gel_id) {
      $gel = new Gel($session,{-name=>$gel_name})->select_if_exists;
      $session->die("Cannot find gel with name $gel_name.")
                                                       unless $gel->id;
      $gel_id = $gel->id;
   }
   my $laneSet = new LaneSet($session,{-gel_id=>$gel_id})->select;
   $session->die("Cannot find lanes with gel id $gel.")
                                                       unless $laneSet;
   @lanes = $laneSet->as_list;
} elsif ( $lane_name ) {
   @lanes = (new Lane($session,{-name=>$lane_name})->select_if_exists);
} elsif ( @lane_id ) {
   map { push @lanes, (new Lane($session,{-id=>$_})->select_if_exists) }
                                                                  @lane_id ;
} else {
   $session->die("No options specified for trimming.");
}

$session->log($Session::Info,"There are ".scalar(@lanes)." lanes to process");

LANE:
foreach my $lane (@lanes) {

   $session->info("Processing lane ".$lane->seq_name);

   # be certain there is enough info for processing the lane
   $session->die("End_sequenced not specified for lane ".$lane->id)
                                           unless $lane->end_sequenced;
   $session->die("Seq_name not specified for lane ".$lane->id)
                                           unless $lane->seq_name;
   $session->die("Gel_id not specified for lane ".$lane->id) 
                                           unless $lane->gel_id;


   $gel = new Gel($session,{-id=>$lane->gel_id})->select
                                             unless $gel && $gel->id;
 
   unless ($enzyme) {
      # determine the digestion identifer from which this comes.
      my $digestion = new Digestion($session,
                    {-name=>&Processing::digestion_id($gel->ipcr_name)}
                                 )->select;

      unless ($digestion && $digestion->enzyme1) {
         $session->die("Cannot determine digestion enzyme for ".
                                                 $lane->seq_name);
      }
      # here is the rule for determining which enzyme was used:
      #    if only enzyme1 is specified, it's used for both
      #    if both enzyme1 and enzyme2 are given, then 1 for P1, P3, P5,...
      #          and enzyme2 for P2, P4, P6,...
      if ($digestion->enzyme2) {
         my $whichPcr;
         if (Processing::ipcr_id($gel->ipcr_name) =~ /.*(\d+)$/ ) {
            $whichPcr = $1
         } else {
            $session->die("Cannot determine IPCR id for $whichPcr");
         }
         $enzyme = ($whichPcr%2)?$digestion->enzyme1:$digestion->enzyme2;
      } else {
         $enzyme = $digestion->enzyme1;
      }
   }
   $session->info("Looking for restriction site of $enzyme.");

   # find the associated phred called sequences.
   my $phred_seq = new Phred_Seq($session,
                         {-lane_id=>$lane->id})->select_if_exists;

   ($session->warn("No sequence for lane $lane->id.") and next LANE)
                                                          unless $phred_seq;
   if ( (defined($phred_seq->v_trim_start) ||
         defined($phred_seq->v_trim_end) ||
         defined($phred_seq->q_trim_start) ||
         defined($phred_seq->q_trim_end) )
           && !$redo) {
      $session->info("Some trimming has been done and redo is false. ".
                     "Skipping this lane.");
      next LANE;
   }
  
     
   my $phred_qual = new Phred_Qual($session,
                         {-phred_seq_id=>$phred_seq->id})->select_if_exists;

   ($session->warn("No quality for lane $lane->id.") and next )
                                                   unless $phred_qual;
      
   my $vector;
   my $t_p;

   # default is to look in the database for trimming protocol based
   # on the collection. overridable on the command line by specifying
   # a vector sequence and an offset
   if ($offset eq '' || !$vector_junc) {

      my $strain = new Strain($session,{-strain_name=>$lane->seq_name})->select;
      unless ($strain && $strain->collection) {
         $session->die("No collection identifier for ".$lane->seq_name);
      }

      my $c_p = new Collection_Protocol($session,
                          {-collection=>$strain->collection,
                           -like=>{end_sequenced=>'%'.$lane->end_sequenced.'%'}}
                                                        )->select;
      unless ($c_p->protocol_id) {
         $session->die("Cannot determine trimming protocol for ".
                                                             $strain->collection);
      }

      $t_p = new Trimming_Protocol($session,{-id=>$c_p->protocol_id})->select;
      if ($t_p->id) {
         $session->log($Session::Info,"Using trimming protocol ".
                                                             $t_p->protocol_name)
                                                          if $t_p->protocol_name;
      } else {
         $session->die("Cannot determine trimming protocol for ".
                                                          $strain->collection);
      }
   
      $vector = new Vector($session,{-id=>$t_p->vector_id})->select;

      # if there is a vector limit, use that to constrain the vector junction

   } else {
      $vector = new Vector($session);
      $vector->sequence($vector_junc);
      $t_p = new Trimming_Protocol($session);
      $t_p->vector_offset($offset);
   }

   my $seq_to_trim;
   if ($t_p->vector_limit) {
      $seq_to_trim = substr($phred_seq->seq,0,$t_p->vector_limit);
   } else {
      $seq_to_trim = $phred_seq->seq;
   }

   my $vStart = vectorTrim($seq_to_trim,$vector->sequence);
   my $foundVec = 0;
   if ( defined ($vStart) ) {
      $vStart += $t_p->vector_offset;
      $session->log($Session::Info,"Sequence starts after vector at $vStart.");
   } else {
      $session->log($Session::Info,"Cannot find vector for ".$lane->seq_name);
      $vStart = 0;
   }

   my $enz = new Enzyme($session,{-enzyme_name=>$enzyme})->select;

   unless ($enz && $enz->restriction_seq) {
      $session->die("Cannot determine restriction sequence for ".
                                                       $enz->enzyme_name);
   }

   (my $cutSeq = uc($enz->restriction_seq)) =~ s/[^ACGT]//g;

   my $vEnd = siteTrim(substr($phred_seq->seq,$vStart),$cutSeq);
   
   # look for the restriction site. We will try again later if we do not
   # have a vector junction but have a high quality region.
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
   foreach my $ruleSet (
       {-thresh=>20,-num=> 5,-start=>$vStart || $t_p->vector_limit,-min=>29},
       {-thresh=>15,-num=>10,-start=>$vStart || $t_p->vector_limit,-min=>9} ) {
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

   # a second try at determining restriction site. Look for the restriction
   # site in the high quality region. This is what will be exported.
   unless ($vStart) {
      $vEnd = siteTrim(substr($phred_seq->seq,$qStart),$cutSeq);
      if ($vEnd) {
         $vEnd += $qStart;
         $session->log($Session::Info,
                "Modified location of seq end is a restriction site at $vEnd.");
      } else {
         $session->log($Session::Info,"No restriction site found.");
      }
   }

   $session->log($Session::Info,"Final quality limits are $qStart, $qEnd.");

   $session->info("Changing vector start location")
            if $vStart && $phred_seq->v_trim_start &&
                                     $vStart != $phred_seq->v_trim_start;
   $session->info("Changing vector end location")
            if $vEnd && $phred_seq->v_trim_end &&
                                     $vEnd != $phred_seq->v_trim_end;
   $session->info("Changing quality start location")
            if $qStart && $phred_seq->q_trim_start &&
                                     $qStart != $phred_seq->q_trim_start;
   $session->info("Changing quality end location")
            if $qEnd && $phred_seq->q_trim_end &&
                                     $qEnd != $phred_seq->q_trim_end;
   # update
   my $is_updated = 0;
   $phred_seq->v_trim_start($vStart) && ($is_updated = 1 ) if $vStart;
   $phred_seq->v_trim_end($vEnd)     && ($is_updated = 1 ) if $vEnd;
   $phred_seq->q_trim_start($qStart) && ($is_updated = 1 ) if $qStart;
   $phred_seq->q_trim_end($qEnd)     && ($is_updated = 1 ) if $qEnd;
   $phred_seq->last_update('now') if $is_updated;
   $phred_seq->update if ($is_updated && !$test);
   

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
   my $baseCtr = 0;
 
   # start from the bottom and work up to get
   # quality cutoff
   $rule->{-start} = 0 unless exists $rule->{-start};
   $rule->{-min} = 0 unless exists $rule->{-min};

   foreach my $i ($rule->{-start}..$#q) {
      if ( $q[$i] < $rule->{-thresh} ) { 
         $loCtr++ if $baseCtr > $rule->{-min};
      } else {
         $loCtr = 0;
      }
      $baseCtr++;

      # $i-$loCtr is the index to the last
      # quality score above the threshold
      # we'll add 1 to make it an 'interbase' coordinate
      # but we have to make sure it doesn't point back
      # to before we started looking.
      # we'll allow cases where the base before the start is above
      # threshold, but the first base after we look is below threshold
      $rule->{-end} = $i - $loCtr + 1
                    unless ($i-$loCtr     < $rule->{-start}-1 ||
                            $i-$loCtr     < 0                 );

      last if ($loCtr > $rule->{-num}) && ($baseCtr > $rule->{-min});
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
   my $r = GH::Sim4::sim4(uc($s),uc($v),{W=>8,K=>12});

   return unless $r->{exons}[0];
   # always look for the last exon of the hit
   return $r->{exons}[-1]{to1};
}

sub siteTrim
{
   my ($s,$v) = (uc($_[0]),uc($_[1]));
   return unless $s =~ /$v/;
   return length($`)+length($&);
}
