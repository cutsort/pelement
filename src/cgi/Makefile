
SRC = login.pl retrieveXML.pl strainReport.pl blastReport.pl

WEBCGIDIR = /www/weasel_94/cgi-bin/pelement

webinstall: $(SRC)
	for I in $?; do (cp $$I $(WEBCGIDIR) ); done

check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check
