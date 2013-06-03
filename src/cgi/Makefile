SRC = pelement.pl \
      login.pl logout.pl \
      strainReport.pl blastReport.pl batchReport.pl gelReport.pl seqReport.pl \
      chromatReport.pl strainStatusReport.pl assemblyReport.pl phenoReport.pl \
      setReport.pl seqStatusReport.pl recheckReport.pl \
      retrieveXML.pl hitMaker.pl seqTrimmer.pl seqDownload.pl \
      batchRegister.pl digRegister.pl ligRegister.pl ipcrRegister.pl \
      seqRegister.pl sampleSheet.pl todoList.pl \
      font.pl regionReport.pl msieRegionReport.pl regionImage.pl  recentBatches.pl \
      oldSetReport.pl

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
	for I in $?; do ( perl -c $$I --installdeps); done
	touch check



