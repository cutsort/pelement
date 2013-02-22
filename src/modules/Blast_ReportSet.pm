=head1 Name

   Blast_ReportSet.pm   A module for the db interface for sets of Blast report thingies.

=head1 Usage

   use Blast_ReportSet;
   $blastReportSet = new Blast_ReportSet([options]);

=cut

package Blast_ReportSet;

use strict;
use Pelement;
use PCommon;
use PelementDBI;
use base 'DbObjectSet';

use Blast_Run;

=head1 insert

   The blast report is a view, so we need to write the insert method
   The model here is that we're going to insert a set of blast_report objects
   that all correspond to the a minimal set of  blast runs/hit/hsps

=cut
sub insert
{
   my $self = shift;
  
   my $args = shift || {};

   #$bRun->date( PCommon::parseArgs($args,'date') || 'now');
   #$bRun->program( PCommon::parseArgs($args,'program') || 'blastn');

   #my $bRun = Blast_Run($self->session);
   #print "here we would insert the report set.<br>\n";

   # test only. everthing is a new run
   # map {$_->insert({program=>'sim4'}) } $self->as_list;

   my $old_db;
   my $old_name;

   my $old_run_id;
   my $old_hit_id;

   # take the list of blast report objects, sort them so that
   # db and names are adjacent, and zoom along. Sorting by
   # score is purely aesthethic

   my @sorted_list = sort { $a->db cmp $b->db ||
                            $a->name cmp $b->name  ||
                            $b->score <=> $a->score } $self->as_list;


   foreach my $b (@sorted_list) {
      if ($b->name eq $old_name && $b->db eq $old_db) {
         $b->run_id($old_run_id);
         $b->hit_id($old_hit_id);
         $b->insert($args);
      } elsif ($b->db eq $old_db) {
         $b->run_id($old_run_id);
         $b->insert($args);
         $old_hit_id = $b->hit_id;
      } else {
         $b->insert($args);
         $old_hit_id = $b->hit_id;
         $old_run_id = $b->run_id;
      }
      $old_db = $b->db;
      $old_name = $b->name;
   }
       
   return $self;
}

1;


