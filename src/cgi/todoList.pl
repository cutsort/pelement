#!/usr/local/bin/perl -I../modules

=head1 NAME

  todoList.pl Web report of the to-do list

=cut

use Pelement;
use PelementCGI;
use Session;

use strict;

my $cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>'Pelement To-Do List',
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();

report($cgi);

print $cgi->footer([
                 {link=>'batchRegister.pl',name=>'Batch Registration'},
                 {link=>'digRegister.pl',name=>'Digestion Registration'},
                 {link=>'ligRegister.pl',name=>'Ligation Registration'},
                 {link=>'ipcrRegister.pl',name=>'iPCR Registration'},
                 {link=>'seqRegister.pl',name=>'Sequencing Registration'},
                  ]);

print $cgi->close_page($cgi);

exit(0);

sub report
{

  my $cgi = shift;

  my $session = new Session({-log_level=>0});

  # query the various to-do views

  {
    my $digList = $session->Digestion_To_DoSet->select;

    my @tableRows = ();
    foreach my $d (sort { $a->batch_date cmp $b->batch_date } $digList->as_list) {
      push @tableRows, [$d->batch,($d->description||$cgi->nbsp),
                        ($d->user_login||$cgi->nbsp),($d->batch_date||$cgi->nbsp)];
    }
    if (@tableRows) {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'Batches ready for Digestion'),
                         $cgi->table({-width=>'70%'},
              $cgi->Tr( [
                 $cgi->th({-width=>'15%'},['Batch']).
                 $cgi->th({-width=>'35%'},['Description']).
                 $cgi->th({-width=>'25%'},['Login','Date']),
                        (map { $cgi->td($_ ) } @tableRows),
                         ] ))),"\n";
    } else {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'No Batches ready for Digestion')),"\n";
    }
  }


  {
    my $ligList = $session->Ligation_To_DoSet->select;

    my @tableRows = ();
    foreach my $d (sort { $a->digestion_date cmp $b->digestion_date } $ligList->as_list) {
      push @tableRows, [$d->name,($d->user_login||$cgi->nbsp),($d->digestion_date||$cgi->nbsp)];
    }
    if (@tableRows) {

      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'Batches ready for Ligation'),
                         $cgi->table({-width=>'70%'},
              $cgi->Tr( [
                 $cgi->th({-width=>'40%'},['Digestion']).
                 $cgi->th({-width=>'30%'},['Login','Date']),
                        (map { $cgi->td($_ ) } @tableRows),
                         ] )
                       )),"\n";
    } else {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'No Batches ready for Ligation')),"\n";
    }
  }


  {
    my $ipcrList = $session->IPCR_To_DoSet->select;

    my @tableRows = ();
    foreach my $d (sort { $a->ligation_date cmp $b->ligation_date } $ipcrList->as_list) {
      push @tableRows, [$d->name,$d->end_type,($d->user_login||$cgi->nbsp),($d->ligation_date||$cgi->nbsp)];
    }
    if (@tableRows) {

      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'Batches ready for iPCR'),
                         $cgi->table({-width=>'60%'},
              $cgi->Tr( [
                 $cgi->th({-width=>'40%'},['Ligation']).
                 $cgi->th({-width=>'10%'},['End']).
                 $cgi->th({-width=>'25%'},['Login','Date']),
                        (map { $cgi->td($_ ) } @tableRows),
                         ] ))),"\n";
    } else {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'No Batches ready for iPCR')),"\n";
    }
  }

  {
    my $gelList = $session->Gel_To_DoSet->select;

    my @tableRows = ();
    foreach my $d (sort { $a->ipcr_date cmp $b->ipcr_date } $gelList->as_list) {
      push @tableRows, [$d->name,($d->user_login||$cgi->nbsp),($d->ipcr_date||$cgi->nbsp)];
    }
    if (@tableRows) {

      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'Batches ready for Sequencing'),
                         $cgi->table({-width=>'70%'},
              $cgi->Tr( [
                 $cgi->th({-width=>'40%'},['iPCR']).
                 $cgi->th({-width=>'30%'},['Login','Date']),
                        (map { $cgi->td($_ ) } @tableRows),
                         ] ))),"\n";
    } else {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'No Batches ready for Sequencing')),"\n";
    }
  }

  {
    my $laneList = $session->Trace_to_doSet->select;

    my @tableRows = ();
    foreach my $d (sort { $a->gel_date cmp $b->gel_date } $laneList->as_list) {
      push @tableRows, [$d->name,($d->user_login||$cgi->nbsp),($d->gel_date||$cgi->nbsp)];
    }
    if (@tableRows) {

      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'Batches ready for Loading or Processing'),
                         $cgi->table({-width=>'70%'},
              $cgi->Tr( [
                 $cgi->th({-width=>'40%'},['Gel']).
                 $cgi->th({-width=>'30%'},['Login','Date']),
                        (map { $cgi->td($_ ) } @tableRows),
                         ] ))),"\n";
    } else {
      print $cgi->center($cgi->div({-class=>'SectionTitle'},
                                   'No Batches ready for Loading or Processing')),"\n";
    }
  }

  $session->exit;
}
