\c pelement

\! wget -q -O- ftp://ftp.flybase.net/releases/current/precomputed_files/map_conversion/genome-cyto-seq.txt.gz |gzip -cd | perl -nle '/^#/? $c=[/^#\s*(\S+)/]->[0] : print join "\t",$c,$_' >genome-cyto-seq.txt

drop table if exists pg_temp.genome_cyto_seq;
create temp table genome_cyto_seq (
  chr text,
  cyto text,
  start int,
  stop int
);
\copy genome_cyto_seq from 'genome-cyto-seq.txt'

insert into cytology (scaffold,start,stop,band,seq_release)
select chr,start,stop,cyto,6
from genome_cyto_seq;

