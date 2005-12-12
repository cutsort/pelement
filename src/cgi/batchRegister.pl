#!/usr/local/bin/perl -I../modules

=head1 NAME

  batchRegister.pl Web registration of batches.

=cut

use Pelement;
use PelementCGI;
use Session;

use CGI::FormBuilder;
use CGI::Session qw/-ip-match/;

use strict;

my $cgi = new PelementCGI;
my $s = new Session({-log_level=>0});

CGI::Session->name("PELEMENTSID");
my $cgiSession = new CGI::Session("driver:PostgreSQL",$cgi,
                                                  {Handle=>$s->db});

my $cookie = $cgi->cookie(PELEMENTSID => $cgiSession->id);

if (!$cgiSession->param('user_id')) {
  $cgiSession->save_param($cgi);
  $cgiSession->param('referrer','batchRegister.pl');
  print $cgi->redirect(-cookie=>$cookie,-uri=>"login.pl");
} elsif ($cgiSession->param('restore_param')) {
  $cgiSession->load_param($cgi);
}

print $cgi->header( -cookie => $cookie );
print $cgi->init_page({-title=>"Batch Registration"});
print $cgi->banner();

my $form = new CGI::FormBuilder(
           header => 0,
           method => 'POST',
           );

$form->field(name=>'strain',type=>'textarea',rows=>'10',cols=>'108');
$form->field(name=>'recheck',options=>[qw(New Recheck Redo Mixed)],
                                                          value=>'New');

if (!$form->submitted || $form->submitted eq 'Format' ||
                                          $form->submitted eq 'Back') {

  $form->field(name=>'duplicates',options=>[qw(Yes No)],value=>'Yes',
                                          label=>'Retain Duplicate IDs');
  $form->field(name=>'sort',options=>[qw(Yes No)],value=>'No',
                                          label=>'Sort IDs');

  my $text = $form->field('strain');
  my @text;
  # split this at white space or commas and expand ranges
  map { push @text, expandRange($_) } split(/[\s,]+/,$text);

  if ($form->field('duplicates') eq 'No') {
    # remove duplicates
    my %text;
    map { $text{$_} = 1 unless $_ =~ /-/ } @text;
    my @uniqued;
    map { push @uniqued, $_ if $text{$_}; $text{$_}=0 } @text;
    @text = @uniqued;
  }
  if ($form->field('sort') eq 'Yes') {
    @text = sort { $a cmp $b } @text;
  }

  # put in eggsplicit newlines as a feeble formatter
  my $text;
  my $ctr = 0;
  while (@text) {
    $text .= shift @text;
    $ctr++;
    $text .= ($ctr%12)?" ":"\n";
  }
  
  $form->field(name=>'strain',value=>$text,force=>1);

  print $cgi->p($cgi->em("You are currently logged in as ",
                                 $cgi->b($cgiSession->param('user_id')))),
        $cgi->center($cgi->hr,
                     $form->render(submit=>['Enter','Format']));

  print $cgi->p($cgi->em(
               qq(To enter a range of strains, type in the first and
                  last id separated by a dash (i.e. EY10001-EY10095)
                  and press 'Format')));

} elsif ( $form->submitted eq 'Enter' || $form->submitted =~ /Swap/ ) {

    # confirmation form:
    my @strains = split(/\s+/,$form->field('strain'));

    if ($form->submitted =~ /Swap/ ) {
      my @str_copy = @strains;
      map { $str_copy[ (12*$_)%95 ]  = $strains[$_] } (0..94);
      @strains = @str_copy;
    }

    $form->field(name=>'recheck',options=>[qw(New Recheck Redo Mixed)],
                                                           value=>'New');
    $form->field(name=>'strain',type=>'hidden',
                                    value=>join(' ',@strains),force=>1);
    $form->field(name=>'recheck',type=>'hidden',
                                    value=>$form->field('recheck'),force=>1);

    my @samples = ( [$cgi->b('A')] );
    my @rows = qw(B C D E F G H);

    my $ctr=0;

    while ( $ctr < 96 ) {
      push @{$samples[-1]}, (shift @strains || $cgi->nbsp);
      $ctr++;
      if (!($ctr%12) ) {
        push @samples, [ $cgi->b(shift @rows) ];
      }
    }
 
    map { $_ = $cgi->td({-align=>'center'},$_) } @samples;

    print $cgi->p($cgi->em("You are currently logged in as ",
                                    $cgi->b($cgiSession->param('user_id'))));
    print $cgi->center($cgi->table({-border=>1,-align=>'center'},
                                    $cgi->Tr({-align=>'center'}, [
                                     $cgi->th({-width=>9},['',(1..12)]),
                                             @samples]))),"\n";
                      
    print $cgi->center($form->render(
              submit=>['Confirm','Back','Swap Ordering Pattern','Cancel']));

} elsif ($form->submitted eq 'Confirm') {
    my $recheck = $form->field('recheck');
    my @strains = split(/\s+/,$form->field('strain'));

    my $user_id = $cgiSession->param('user_id');
    # make sure this is set
    (print $cgi->em("Your user id is not known.") and $s->die) unless $user_id;
    print $cgi->p($cgi->em("You are currently logged in as $user_id"));

    $s->db_begin;
    # see if these are known strains for a new batch
    if ($recheck eq 'New') {
      # we need to register the strains
      map { if( $_ !~ /blank/i && $_ !~ /^CTR/ ) {
              print $cgi->center($cgi->b(
              "Problem: $_ is an existing strain and is marked new.")) and
                         $s->die if $s->Strain({-strain_name=>$_})->db_exists;
              $s->Strain({-strain_name=>$_,
                          -collection=>substr($_,0,2),
                          -status=>'new',
                          -registry_date=>'today'})->insert;
            }
          } @strains;
    } elsif ($recheck eq 'Recheck' || $recheck eq 'Redo') {
      # these should be registered
      map { if ( $_ !~ /blank/i) {
              print $cgi->center($cgi->b(
              "Problem: $_ is not an existing strain and is marked recheck.")) and
                    $s->die unless $s->Strain({-strain_name=>$_})->db_exists
             }
          } @strains;
    } else {
      # mixed bags need to be checked to see what needs to be verified
      map { if ( $_ !~ /blank/i && $_ !~ /^CTR/ ) {
              unless ( $s->Strain({-strain_name=>$_})->db_exists ) {
                $s->Strain({-strain_name=>$_,
                          -collection=>substr($_,0,2),
                          -status=>'new',
                          -registry_date=>'today'})->insert;
              }
           
            }
          } @strains;
    }

    # now register the batch
    my $batch = $s->Batch({-user_login=>$user_id,
                           -batch_date=>'today',
                           -type=>$recheck});
    $batch->insert;
    (print $cgi->center($cgi->b("Problem: Cannot create new batch")) and $s->die)
                unless $batch && $batch->id;

    # and the samples
    map { if ($strains[$_] !~ /blank/i) {
            my $sample = $s->Sample({-batch_id=>$batch->id,
                       -well=>substr('abcdefgh',int($_/12),1).($_%12+1),
                       -strain_name=>$strains[$_]});
            $sample->insert;
            (print $cgi->center($cgi->b("Problem: Cannot create new sample")) and $s->die)
                  unless $sample->id; 
          }   } (0..$#strains);
         
    $s->db_commit;

    print $cgi->center("Batch ".$cgi->a({-href=>'batchReport.pl?batch='.$batch->id},
                                        $batch->id)." registered.");

}
   

print $cgi->footer([
                 {link=>"batchReport.pl",name=>"Batch Report"},
                 {link=>"strainReport.pl",name=>"Strain Report"},
                 {link=>"gelReport.pl",name=>"Gel Report"},
                 {link=>"strainStatusReport.pl",name=>"Strain Status Report"},
                  ]);

print $cgi->close_page();

$s->exit;
exit(0);

sub expandRange
{
  my $range = shift;

  my ($start,$end) = split(/-/,$range,2);

  return $start unless $end;

  my @array;

  if (length($start) > length($end) ) {
    my $new_end = $start;
    my $l = length($end);
    $new_end =~ s/.{$l}$/$end/;
    $end = $new_end;
  }

  (my $start_n = $start) =~ s/^(.*\D)(\d+)$/$2/;
  my $start_base = $1;
  (my $end_n = $end) =~ s/^(.*\D)(\d+)$/$2/;
  my $end_base = $1;

  return unless $start_base eq $end_base;

  my $num_len = length($start) - length($start_base);

  foreach my $i ($start_n..$end_n) {
    push @array, sprintf( "%s%0${num_len}d",$start_base,$i);
  }

  return @array;
}
