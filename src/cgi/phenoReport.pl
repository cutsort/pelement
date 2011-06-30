#!/usr/local/bin/perl -I../modules

=head1 NAME

  phenoReport.pl Web report of the genotype/phenotype information.

=cut

use Pelement;
use Session;
use Strain;
use Phenotype;
use PelementCGI;
use PelementDBI;

$cgi = new PelementCGI;

print $cgi->header();
print $cgi->init_page({-title=>$cgi->param('strain')." Phenotype Report",
                       -script=>{-src=>'/pelement/sorttable.js'},
                       -style=>{-src=>'/pelement/pelement.css'}});
print $cgi->banner();

if ($cgi->param('strain')) {
   if ($cgi->param('Enter')) {
      $session = updatePhenotypeTable($cgi);
   }
   reportStrain($cgi,$session);
} else {
   selectStrain($cgi);
}

print $cgi->footer();
print $cgi->close_page();

exit(0);

sub selectStrain
{

   my $cgi = shift;

   print
     $cgi->center(
       $cgi->h3("Enter the Strain name:"),"\n",
          $cgi->br,
          $cgi->start_form(-method=>"get",-action=>"phenoReport.pl"),"\n",
             $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
                $cgi->Tr( [
                   $cgi->td({-align=>"right",-align=>"left"},
                                       ["Strain Name",$cgi->textfield(-name=>"strain")]),
                   $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Report")]),
                   $cgi->td({-colspan=>2,-align=>"center"},[$cgi->reset(-name=>"Clear")]) ]
                ),"\n",
             ),"\n",
          $cgi->end_form(),"\n",
          ),"\n";
}

sub updatePhenotypeTable
{
#
#   my $cgi = shift;
#   my $session = new Session({-log_level=>0});
#
#
#   # see what we have
#   my $id = $cgi->param('id');
#   my $strain = $cgi->param('strain');
#   my $viable = uc($cgi->param('is_homozygous_viable'));
#   my $fertile = uc($cgi->param('is_homozygous_fertile'));
#   my $derived_cytology = $cgi->param('derived_cytology');
#   my $associated_aberration = $cgi->param('associated_aberration');
#   my $phenotype = $cgi->param('phenotype');
#   my $strain_comment = $cgi->param('strain_comment');
#   my $phenotype_comment = $cgi->param('phenotype_comment');
#
#   my $pheno;
#   my $action;
#   # consistency checks
#   if ($id) {
#      $pheno = new Phenotype($session,{-id=>$id})->select_if_exists;
#      $action = 'update';
#      if ($pheno->strain_name ne $strain) {
#         reject($cgi,"There is an error in the CGI parameters.");
#         return $session;
#      }
#   } else {
#      $pheno = new Phenotype($session);
#      $action = 'insert';
#   }
#
#   if ($viable ne 'Y' && $viable ne 'N' && $viable ne 'U') {
#      reject($cgi,"There is an error in the value of is_homozygous_viable.");
#      return $session;
#   }
#   if ($fertile ne 'Y' && $fertile ne 'N' && $fertile ne 'U') {
#      reject($cgi,"There is an error in the value of is_homozygous_fertile.");
#      return $session;
#   }
#
#   # clean-ups.
#   map { s/[\n\r]/ /gs } ($derived_cytology,$associated_aberration,$phenotype,$strain_comment,$phenotype_comment);
#   map { s/\s+/ /g } ($derived_cytology,$associated_aberration,$phenotype,$strain_comment,$phenotype_comment);
#   map { s/[^A-Za-z0-9.,-'"\/\\]//g } ($derived_cytology,$associated_aberration,$phenotype,$strain_comment,$phenotype_comment);
#
#   $pheno->is_homozygous_viable($viable);
#   $pheno->is_homozygous_fertile($fertile);
#   $pheno->derived_cytology($derived_cytology);
#   $pheno->associated_aberration($associated_aberration);
#   $pheno->phenotype($phenotype);
#   $pheno->strain_comment($strain_comment);
#   $pheno->phenotype_comment($phenotype_comment);
#
#   #$pheno->$action;
#
#   #print $cgi->center($cgi->h1("The $action on the phenotype table was successful.")),"\n";
#   print $cgi->center($cgi->h1("Still testing. No updates are done.")),"\n";
#
#   return $session;
}

sub reject
{
   print shift->h3(shift),"\n";;
}

sub reportStrain
{
   my $cgi = shift;

   my $session = shift || new Session({-log_level=>0});

   my $strain;
   if ($cgi->param('strain') ) {
      $strain = new Strain($session,{-strain_name=>$cgi->param('strain')});
   }

   if ( !$strain->db_exists ) {
      print $cgi->center($cgi->h2("No record for Strain ".
                                   $strain->strain_name.".")),"\n";
      return;
   }

   $strain->select;

   my $pheno = new Phenotype($session,{-strain_name=>$strain->strain_name})->select_if_exists;

   $pheno->is_homozygous_viable('U') unless $pheno->is_homozygous_viable;
   $pheno->is_homozygous_fertile('U') unless $pheno->is_homozygous_fertile;

   my @tableRows = ();
   foreach my $col qw(Is_Homozygous_Viable Is_Homozygous_Fertile ) {
      (my $label = $col) =~ s/_/ /g;
      my $db = lc($col);
      push @tableRows , $cgi->td({-align=>"right",-align=>"left"},
                                [$label,$cgi->popup_menu(-name=>$db,-values=>['Y','N','U'],-default=>$pheno->$db)]);
   }
   foreach my $col qw(Derived_Cytology) {
      (my $label = $col) =~ s/_/ /g;
      my $db = lc($col);
      push @tableRows , $cgi->td({-align=>"right",-align=>"left"},
                                [$label,$cgi->textfield(-name=>$db,-value=>$pheno->$db)]);
   }
   foreach my $col qw(Associated_Aberration Phenotype Strain_Comment Phenotype_Comment) {
      (my $label = $col) =~ s/_/ /g;
      my $db = lc($col);
      push @tableRows , $cgi->td({-align=>"right",-align=>"left"},
                                [$label,$cgi->textarea(-name=>$db,-rows=>10,-cols=>60,-value=>$pheno->$db)]);
   }
   print 
       $cgi->center(
       $cgi->h3("Enter changes in the text fields and press Enter when done"),"\n",
       $cgi->br,$cgi->h3("If and when I turn this on, that is."),"\n",
          $cgi->br,
          $cgi->start_form(-method=>"post",-action=>"phenoReport.pl"),"\n",
             $cgi->hidden(-name=>'strain',-value=>$strain->strain_name),"\n",
             $cgi->hidden(-name=>'id',-value=>$pheno->id),"\n",
             $cgi->table( {-bordercolor=>$HTML_TABLE_BORDERCOLOR},
                $cgi->Tr( [@tableRows,
                   $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Enter")]) ]
                ),"\n",
             ),"\n",
          $cgi->end_form(),"\n",
          ),"\n";

   $session->exit();
}
