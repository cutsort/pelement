package Pelement;
require Exporter;
use Getopt::Long;

@ISA = qw(Exporter);
@EXPORT = qw(
    $PELEMENT
    $PELEMENT_USER
    $PELEMENT_HOME
    $PELEMENT_BIN
    $PELEMENT_HTML
    $PELEMENT_WEB_CACHE
    $PELEMENT_XML
    $PELEMENT_PLATFORM_BIN
    $PELEMENT_INBOX
    $PELEMENT_LOG
    $PELEMENT_TRACE
    $PELEMENT_TMP
    $PELEMENT_NOTIFY
    $PELEMENT_DB_DBI
    $PELEMENT_DB_CONNECT

    $PELEMENT_VECTORS

    $PELEMENT_PHRAPBIN
    $PELEMENT_PHREDBIN
    $PELEMENT_CROSS_MATCHBIN
    $PELEMENT_JAVABIN

    $FLYBASE_SCHEMA

    $NCBI_BLAST_BIN_DIR
    $BLAST_DB
    $BLAST_PATH

  ); 

# high level directory locations
$PELEMENT = "/data/pelement/";
$PELEMENT_USER = "pelement";
$PELEMENT_HOME = "/data/pelement/";
$PELEMENT_BIN = $PELEMENT_HOME . "/scripts/";
$PELEMENT_PLATFORM_BIN = $PELEMENT_BIN . "$^O/";
$PELEMENT_HTML = "/opt/http/cgi-bin/pelement/";

### directories for cgi scripts
# this is for the private (test) server

$PELEMENT_TRACE   = $PELEMENT . "trace/";
$PELEMENT_INBOX   = $PELEMENT_TRACE . "INBOX/";
$PELEMENT_XML     = $PELEMENT . "xml/";
$PELEMENT_LOG     = $PELEMENT . "log/";
$PELEMENT_TMP     = $PELEMENT . "tmp/";
$PELEMENT_WEB_CACHE = $PELEMENT . "tmp/webcache/";
$PELEMENT_VECTORS = $PELEMENT . "vectors/";

# e-mail errors to these people
$PELEMENT_NOTIFY = "bbooth\@fruitfly.org";

# db server
$PELEMENT_DB_DBI     = "Pg";
# whatever it takes to connect.
$PELEMENT_DB_CONNECT = "dbname=pelement;host=eel.lbl.gov";

#######################################################################
### Paths to programs labtrack runs

if ($^O eq 'darwin') {
  $PELEMENT_PHREDBIN = "/usr/local/bdgp/consed_mac-23.0/bin/phred";
  $PELEMENT_PHRAPBIN = "/usr/local/bdgp/consed_mac-23.0/bin/phrap";
  $PELEMENT_CROSS_MATCHBIN = "/usr/local/bdgp/consed_mac-23.0/bin/cross_match";
  $NCBI_BLAST_BIN_DIR = "/usr/local/bin/";
}
elsif ($^O eq 'linux') {
  $PELEMENT_PHREDBIN = "/usr/local/bdgp/bin/phred";
  $PELEMENT_PHRAPBIN = "/usr/local/bdgp/bin/phrap";
  $PELEMENT_CROSS_MATCHBIN = "/usr/local/bdgp/bin/cross_match";
  $NCBI_BLAST_BIN_DIR = "/usr/local/bdgp/ncbi-blast-2.2.26+/bin/";
}
else {
  die "Unsupported platform: $^O";
}

$ENV{PHRED_PARAMETER_FILE} = "/usr/local/bdgp/etc/phredpar.dat";

# include paths for blast tools
$BLAST_PATH = "/usr/local/bdgp/wublast-2.0-030822/";
$BLAST_DB = "/data/pelement/blast/";
$ENV{BLASTDB} = $BLAST_DB;
$ENV{BLASTMAT} = "$BLAST_PATH/matrix";
$ENV{BLASTFILTER} = "$BLAST_PATH/filter";

# path to bdgp 'common' modules
$ENV{FLYBASE_MODULE_PATH} = $FLYBASE_MODULE_PATH;

$FLYBASE_SCHEMA = 'fb2013_04';

1;
