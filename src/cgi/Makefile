SRC = login.pl retrieveXML.pl strainReport.pl blastReport.pl \
      batchReport.pl gelReport.pl seqReport.pl retrieveXML.pl \
      chromatReport.pl

install: check
	for I in $(SRC); do (/bin/sed -e '1s/-I\.\./-I$(SEDINSTALLDIR)/' $$I > $(INSTALLDIR)/$$I ); done
	for I in $?; do (cp $$I $(INSTALLDIR) ); done

check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check
