SRC = login.pl retrieveXML.pl strainReport.pl blastReport.pl \
      batchReport.pl gelReport.pl seqReport.pl retrieveXML.pl \
      chromatReport.pl strainStatusReport.pl assemblyReport.pl phenoReport.pl \
      seqStatusReport.pl

install: check
	for I in $(SRC); do (/bin/sed -e '1s:-I\.\.:-I$(INSTALLDIR):' $$I > $(INSTALLDIR)/$$I; chmod +x $(INSTALLDIR)/$$I ); done

check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check
