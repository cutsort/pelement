#!/usr/local/bin/perl -I../modules

use Pelement;
use PelementCGI;
use WebSession;

my $cgi = new PelementCGI;

my $user = $cgi->param('user');
my $pass = $cgi->param('pass');
my $referer = $cgi->param('referer') || $ENV{HTTP_REFERER};

print $cgi->header(),$cgi->banner(),"\n";

if (!$user && !$pass) {
   print
      $cgi->start_html(-title => "Pelement Login", -bgcolor => "#fcffff"),
      $cgi->center(
         $cgi->h3("Login to the Pelement Project Web Site"),"\n",
            $cgi->br,
               $cgi->start_form(-method=>"post",-action=>"/cgi-bin/pelement/login.cgi"),"\n",
                  $cgi->table(
                     $cgi->Tr( [
                        $cgi->td({-align=>"right",-align=>"left"},
                                          ["User:",$cgi->textfield(-name=>"user")]),
                        $cgi->td({-align=>"right",-align=>"left"},
                                          ["Password:",$cgi->password_field(-name=>"pass")]),
                        $cgi->td({-colspan=>2,-align=>"center"},[$cgi->submit(-name=>"Login")])
                               ]
                     ),"\n",
                  ),
               $cgi->end_form(),"\n",
         $cgi->em(qq(This site uses cookies to track logins in the database. If cookies are
                     disabled in your browser then you will be able to query the database without
                     typing in your password as often.)),
      ),"\n";

} else {

   my $db = PelementDBI($PELEMENT_DB_CONNECT);

   my $storedPass = $db->select(qq(select code from person where login='$user'));

   if (crypt($pass,salt(substr($storedPass,0,2))) eq $storedPass ) {
      # create a session identifier based on this username.
      my $webSession = new WebSession($db,$user);
      print $cgi->p(qq(Login was successful. Session identifier is ).$webSession->webId),"\n";
   }

   $db->disconnect();
  
}

print $cgi->footer,$cgi->end_html,"\n";

