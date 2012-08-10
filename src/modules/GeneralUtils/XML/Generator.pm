package GeneralUtils::XML::Generator;

=head1 NAME

GeneralUtils::XML::Generator

=head1 DESCRIPTION

Class for generating xml; either on stdout or to a file (can be
extended to output to a string if required)

The idea of this class is to allow objects that dump xml to specify
only the "logic" and not worry about the context and specifics. See
WebReports::AnnotationOut->to_xml() for an example

=head1 AUTHOR - Chris Mungall

cjm@fruitfly.berkeley.edu

=cut

use Carp;
use Exporter;
use strict;
use GeneralUtils::Structures qw(rearrange);
use vars qw($TAB $COLLEN @ISA @EXPORT_OK);
use FileHandle;


$TAB = "  ";
$COLLEN = 60;

=head1 PUBLIC METHODS

=head2 new

  Usage   - $xmlgen = GeneralUtils::XML::Generator->new();
  Returns - GeneralUtils::XML::Generator
  Args    - -file, -cgi

generates xml on stdout given no args; given a file it will output to
a file. given a CGI handle, it will output to stdout, passing output through escapeHTML

=cut

sub new {
    my $proto = shift; my $class = ref($proto) || $proto;;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}

sub _initialize {
    my $self = shift;
    my ($file, $cgi, $fh) =
      rearrange(['file', 'cgi', 'fh'], @_);
    $self->{_cgi} = $cgi;
    if ($file) {
        $self->{_fh} = FileHandle->new(">$file") || confess("can't write to $file");
    }
    elsif ($fh) {
	$self->{_fh} = $fh;
    }
    else {
	$self->{_fh} = *STDOUT;
	$self->{is_stdout} = 1;
    }
    $self->{level} = 0;
    $self->{tags} = [];

}

sub DESTROY {
    my $self = shift;
    if (!$self->{is_stdout}) {
        $self->{_fh}->close if $self->{_fh};
    }
}

sub kill {
    my $self = shift;
    if (!$self->{is_stdout}) {
        $self->{_fh}->close  if $self->{_fh};
    }
}


=head2 header

-Usage: $generator->header();

Summary:  Prints the XML header line:<?xml version="1.0"?>

=cut


sub header {
    my $self = shift;
    $self->output('<?xml version="1.0"?>'."\n");
}

=head2 stylesheet

-Usage $generator->stylesheet("stylesheet-url")

-Summary - adds a link to a stylesheet from
the xml documents for processors (like mozilla)

=cut

sub stylesheet {
    my $self = shift;
    my $stylesheet = shift;

   $self->output("<?xml-stylesheet type=\"text/xsl\" href=\"$stylesheet\" ?>\n\n");
   
}

=head2 open

=cut

sub open {
    my $self = shift;
    my $tag = shift;
    confess("tag must be scalar, not $tag") if ref($tag);
#    print STDERR "OPEN:$tag\n" if $ENV{SQL_TRACE};
    my @attrs = @_;
    $self->_tab();
    $self->output("<$tag");
    for (my $i=0; $i < @attrs; $i+=2) {
	if (defined($attrs[$i+1])) {
            my $att = $attrs[$i+1];
            ##  &quot; escapes a " in an xml att
            $att =~ s/\"/\&quot\;/g;
	    $self->output(" $attrs[$i]=\"$att\"");
	}
    }
    $self->output(">");
    $self->output("\n") unless $self->{_pack};
    $self->{level}++;
    push(@{$self->{tags}}, $tag);
}

=head2 close

=cut

sub close {
    my $self = shift;
    my $tag = shift;

    my @tags = @{$self->{tags}};
    # recursively close unclosed tags if API user forgets to do this:
    while (@tags &&
	   $tag ne $tags[$#tags]) {
	$self->close($tags[$#tags]);
	@tags = @{$self->{tags}};
    }
    if ($tag ne  $tags[$#tags]) {
	confess("$tag was never opened OR !");
    }
    $self->{level}--;
    $self->_tab() unless $self->{_pack};
    $self->output("</$tag>\n");
    $self->{_pack} = 0;
    pop(@{$self->{tags}});
}

sub tag {
    my $self = shift;
    my $tag = shift;
    confess("tag must be scalar, not $tag") if ref($tag);
#    print STDERR "OPEN:$tag\n" if $ENV{SQL_TRACE};
    my @attrs = @_;
    $self->_tab();
    $self->output("<$tag");
    for (my $i=0; $i < @attrs; $i+=2) {
        if (defined($attrs[$i+1])) {
            my $att = $attrs[$i+1];
            ##  &quot; escapes a " in an xml att
            $att =~ s/\"/\&quot\;/g;
            $self->output(" $attrs[$i]=\"$att\"");
        }
    }
    $self->output("/>");
    $self->output("\n") unless $self->{_pack};
}



=head2 pack

  Usage   -
  Returns -
  Args    -

makes the generator go into pack mode (xml takes up less vertical real
estate)

automatically switches back after the current tag

=cut

sub pack {
    my $self = shift;
    $self->{_pack} = 1;
}

=head2 pcdata

outputs pcdata

args: element [str], pcdata [str]

=cut

sub pcdata {
    my $self = shift;
    my $element = shift;
    my $pcdata = shift;

    if (!defined($pcdata)) {
	return;
    }
    if (!$self->opt &&
        length($pcdata) < ($COLLEN - $self->{level} * length($TAB))) {
        $self->pack;
    }
    $self->open($element);
    $self->body($pcdata);
    $self->close($element);
}


=head2 body

args: body [str]

tabs to indent level and outputs the body string;

NOTE: if body contains newlines, EACH LINE will be indented (for
purely aesthetic reasons); you'll have to add your own method here if
this isn't the behaviour you want

=cut

sub body {
    my $self = shift;
    my $body = shift;

    #need to globally subs--Shu
    $body =~ s/\&/\&amp\;/g;
    $body =~ s/\</\&lt\;/g;
    $body =~ s/\>/\&gt\;/g;
    if ($self->{_pack} || $self->opt) {
        $self->output($body);
    }
    else {
        map {
            my $n = "\n";
            $self->_tab() unless $self->{_pack};
            $self->output("$_$n");
        } split(/\n/, $body);
    }
}

=head2 comment

=cut

sub comment {
    my $self = shift;
    my $comment = shift;
    $self->_tab;
    $self->output("<!-- $comment -->\n");
}

sub _tab {
    my $self = shift;
    my $fh = $self->{_fh};
    print $fh $TAB x $self->{level};
}


=head2 opt

  Usage   -
  Returns -
  Args    -

=cut

sub opt {
    my $self = shift;
    $self->{_opt} = shift if @_;
    return $self->{_opt};
}


sub output {
    my $self = shift;
#  Removing SpellGreek - colin 03apr02
#    my $str = spell_greek(shift);
    my $str = shift;
    my $fh = $self->{_fh};
    if ($self->{_cgi}) {
	print $fh $self->{_cgi}->escapeHTML($str);
    }
    else {
	print $fh $str;
    }
}

1;
