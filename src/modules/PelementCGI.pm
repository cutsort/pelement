=head1 NAME

   PelementCGI

   The overloaded CGI interface with some Pelement specific processing
   methods.

=head1 USAGE

   use PelementCGI;
   $db = new PelementCGI();

=cut

package PelementCGI;
use CGI;

@ISA = qw(CGI);

sub init_page
{
  return qq(
       <html>
       <body bgcolor=#fefefa background="">
           );
}

sub close_page
{
   return qq(
       </body>
       </html>
            );
}

sub banner
{
  return qq(
       <center><h3>BDGP Pelement Insertion Data Tracking DB<h3></center>
       <hr />
          );

}

sub footer
{
  return qq(
       <hr />
       <center><h3>BDGP Pelement Insertion Data Tracking DB<h3></center>
          );
}

1;
