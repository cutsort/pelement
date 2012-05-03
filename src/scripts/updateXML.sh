#!/bin/csh

cd `dirname $0`

foreach i (AE.1 AE.2 AE.3 AE.4)
   ~joe/bin/doall /data/pelement/scripts/generateXML.pl  $i >& /dev/null &
end

~joe/bin/doall /data/pelement/scripts/generateXML.pl  AE.5

sleep 3600

cd /data/pelement/xml

touch pelementXML.tar
touch pelementXML.tar.gz
rm -f pelementXML.tar
rm -f pelementXML.tar.gz

tar cvf pelementXML.tar A*.xml 21*.xml *extension*.xml

gzip pelementXML.tar

