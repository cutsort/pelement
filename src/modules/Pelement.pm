package Pelement;
require Exporter;

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

    $FLYBASE_MODULE_PATH
    $BDGP_MODULE_PATH
    $GENOMIC_BIN

    $BLAST_DB
    $BLAST_PATH

  ); 

# high level directory locations
$PELEMENT = "/data/pelement/";
$PELEMENT_USER = "pelement";
$PELEMENT_HOME = "/users/pelement/";
$PELEMENT_BIN = $PELEMENT_HOME . "/bin/";
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
$PELEMENT_NOTIFY = "joe\@fruitfly.org";


# db server
$PELEMENT_DB_DBI     = "Pg";
# whatever it takes to connect.
$PELEMENT_DB_CONNECT = "dbname=pelement;host=sin";

# other executable directories
$GENOMIC_BIN = "/usr/local/bdgp/bin/";

#######################################################################
### Paths to programs labtrack runs

$PELEMENT_PHREDBIN = "/usr/local/bdgp/bin/phred";
$PELEMENT_PHRAPBIN = "/usr/local/bdgp/bin/phrap";
$PELEMENT_CROSS_MATCHBIN = "/usr/local/bdgp/bin/cross_match";
$ENV{PHRED_PARAMETER_FILE} = "/usr/local/bdgp/etc/phredpar.dat";

# include paths for java
$ENV{PATH} = "$ENV{PATH}:/tools/sequence/bin/:/tools/java/jdk1.1.5/bin/";
$ENV{CLASSPATH} = "/usr/java1.1/lib/classes.zip/:$PELEMENT_USER/classes/:$PELEMENT_USER/lib/ngsdk.jar";
$PELEMENT_JAVABIN = "/bin/java";

# include paths for blast tools
$BLAST_PATH = "/usr/local/bdgp/wublast/";
$BLAST_DB = "/data/pelement/blast/";
$ENV{BLASTDB} = $BLAST_DB;
$ENV{BLASTMAT} = "$BLAST_PATH/matrix";
$ENV{BLASTFILTER} = "$BLAST_PATH/filter";

# path to bdgp 'common' modules
$BDGP_MODULE_PATH = "/usr/local/bdgp/lib/perl";
$FLYBASE_MODULE_PATH = $ENV{FLYBASE_MODULE_PATH} || $PELEMENT_HOME."software/perl-modules/";
$ENV{FLYBASE_MODULE_PATH} = $FLYBASE_MODULE_PATH;

1;
