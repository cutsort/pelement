=head1 NAME

   PelementCGI

   The overloaded CGI interface with some Pelement specific processing
   methods.

=head1 USAGE

   use PelementCGI;
   $db = new PelementCGI();

=cut

package PelementCGI;

use Exporter;
use CGI;

@ISA = qw(Exporter CGI);

@EXPORT = qw( $HTML_BODY_BGCOLOR
              $HTML_TABLE_HEADER_BGCOLOR
              $HTML_TABLE_HEADER_BGCOLOR2
              $HTML_TABLE_BORDERCOLOR
            );

# constants used in colors, borders, widths, ...

$HTML_BODY_BGCOLOR = "#FEFEFA";
$HTML_TABLE_HEADER_BGCOLOR  = "#A2C4D8"; # blue-gray
$HTML_TABLE_HEADER_BGCOLOR2 = "#C1D7E5"; # lighter blue-gray
$HTML_TABLE_BORDERCOLOR     = "#E0EAF2"; # brighter


=head1 new

  the overloaded constructor. We're keeping track of whether we're spewing
  html, text, or whatever.

=cut

sub new
{
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  # keep track of what we're printing out.
  $self->{format} = $self->param('format') || 'html';

  return $self;

}

=head1 format

  A getter/setter for the format

=cut
sub format
{
   my $self = shift;
   $self->{format} = shift if (@_);
   return $self->{format};
}

sub init_page
{
  my $self = shift;
  return $self->start_html({-bgcolor=>$HTML_BODY_BGCOLOR}) if $self->format eq 'html';
  return $self->start_html({-bgcolor=>$HTML_BODY_BGCOLOR})."<pre>\n";
  
 
}

sub close_page
{
   my $self = shift;
   return $self->end_html if $self->format eq 'html';
   return "</pre>".$self->end_html;

}

sub banner
{
  my $self = shift;
  return $self->center($self->h3('BDGP Pelement Insertion Data Tracking DB')).
            "\n".$self->hr."\n";

}

sub footer
{
  my $self = shift;
  my $links = shift;

  my $formattedLinks = [];
  map { push @$formattedLinks, $self->a({-href=>$_->{link}},$_->{name}) } @$links;

  my $table;
  $table = $self->table($self->Tr([$self->td($formattedLinks)]))."\n" if @$formattedLinks;

  return $self->hr."\n".
         $self->center($self->h3('BDGP Pelement Insertion Data Tracking DB'),
                       $self->br,"\n",$table);
}


=head format_plate

  a utility for formatting 'plate'-like tables of a collection of rows and columns,
  intended for use when formatting a 96-well plate. We pass along a list ref of
  the rows, a list ref of the columns, and a hash of entries. An optional 4'th
  argument is the attributes attached to each cell.

  The cell contents are specifed as $cRef->{$row:$col} where $row and $col are
  entries in the row and column lists.

  We're being silly and trying to set this up so that there are no assumptions
  about the number of wells.

=cut
sub format_plate
{

   my $self = shift;
   my $rRef = shift;
   my $cRef = shift;
   my $cHashRef = shift;
   my $att = shift || {};

   my @tableRows = ();

   my $colWidth = int(100/(scalar(@$cRef)+.5) + .5);
 
   my @row = ();
   map {push @row , $_} @$cRef;
   push @tableRows, $self->th({-width=>($colWidth/2).'%'},[$self->nbsp]).
                    $self->th({-width=>$colWidth.'%',-align=>'center',-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR2},\@row);

   foreach my $r (@$rRef) {
      @row = ();
      map { push @row, exists($cHashRef->{"$r:$_"})?$cHashRef->{"$r:$_"}:$self->nbsp} @$cRef;
      map { push @t, '' } @$cRef;
      push @tableRows, $self->th({-bgcolor=>$HTML_TABLE_HEADER_BGCOLOR2},$r).
                       $self->td({-align=>'center'},\@row);
   }
   return $self->table({-bordercolor=>$HTML_TABLE_BORDERCOLOR,-border=>1},
                 $self->Tr( \@tableRows));
}

=head1 overloaded CGI.pm elements

   We want to be able to have a variety of presentation format
   Depending on a cgi parameter 'format', we can display as html,
   text, ...

=cut

sub td
{
   my $self = shift;
   return $self->SUPER::td(@_) if $self->format eq 'html';
   my $arg = shift;
   $arg = shift if ref($arg) eq 'HASH';

   if (ref($arg) eq 'ARRAY') {
      return join("\t",@$arg)."\t";
   } else {
      return join("\t",($arg,@_))."\t";
   }
}
sub th
{
   my $self = shift;
   return $self->SUPER::th(@_) if $self->format eq 'html';
   my $arg = shift;
   $arg = shift if ref($arg) eq 'HASH';

   if (ref($arg) eq 'ARRAY') {
      return join("\t",@$arg)."\t";
   } else {
      return join("\t",($arg,@_))."\t";
   }
}

sub Tr
{
   my $self = shift;
   return $self->SUPER::Tr(@_) if $self->format eq 'html';

   my $arg = shift;
   $arg = shift if ref($arg) eq 'HASH';
      
   if (ref($arg) eq 'ARRAY') {
      return join("\n",@$arg);
   } else {
      return join("\n",($arg,@_));
   }
   
}

sub table
{
   my $self = shift;
   return $self->SUPER::table(@_) if $self->format eq 'html';
   my $arg = shift;
   $arg = shift if ref($arg) eq 'HASH';
      
   return "\n".join(" ",($arg,@_))."\n";
   
}

sub a
{
   my $self = shift;
   return $self->SUPER::a(@_) if $self->format eq 'html';
   my $arg = shift;
   $arg = shift if ref($arg) eq 'HASH';
   return join(" ",($arg,@_));
}
   
sub nbsp
{
   my $self = shift;
   return '&nbsp' if $self->format eq 'html';
   return ' ';
}


sub hr
{
   my $self = shift;
   return $self->SUPER::hr(@_) if $self->format eq 'html';

   return "\n".('-'x80)."\n";
}

sub center {
   my $self = shift;
   return $self->SUPER::center(@_) if $self->format eq 'html';
   return @_;
}

sub h1 {
   my $self = shift;
   return $self->SUPER::h1(@_) if $self->format eq 'html';
   return @_;
}

sub h2 {
   my $self = shift;
   return $self->SUPER::h2(@_) if $self->format eq 'html';
   return @_;
}

sub h3 {
   my $self = shift;
   return $self->SUPER::h3(@_) if $self->format eq 'html';
   return @_;
}

sub br {
   my $self = shift;
   return $self->SUPER::br(@_) if $self->format eq 'html';
   return ' ';
}

sub p {
   my $self = shift;
   return $self->SUPER::p(@_) if $self->format eq 'html';
   return @_,"\n";
}

1;
