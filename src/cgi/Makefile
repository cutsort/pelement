SRC = login.pl retrieveXML.pl strainReport.pl blastReport.pl \
      batchReport.pl gelReport.pl seqReport.pl retrieveXML.pl \
      chromatReport.pl strainStatusReport.pl assemblyReport.pl phenoReport.pl \
      seqStatusReport.pl recheckReport.pl hitMaker.pl seqTrimmer.pl setReport.pl

IMG = images/2L.png images/2R.png images/3L.png images/3R.png \
      images/4.png images/X.png images/left.png images/left2.png \
      images/right.png images/right2.png images/up.png

install: check module_install img_install
	for I in $(SRC); do (/bin/sed -e '1s:-I\.\.:-I$(INSTALLDIR):' $$I > $(INSTALLDIR)/$$I; chmod +x $(INSTALLDIR)/$$I ); done

module_install:
	cd ../modules ; INSTALLDIR=$(INSTALLDIR) make install

img_install: $(IMG)
	for I in $?; do ( cp $$I $(INSTALLDIR)/../../htdocs/pelement/images/ ); done

check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check



