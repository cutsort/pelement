SRC = alignSeq.pl baseCaller.pl	generateXML.pl runBlast.pl \
	seqTrimmer.pl generateFlyBaseXML.pl seqImporter.pl dumpSeq.pl \
	importFromFasta.pl importQualFromFasta.pl buildConsensus.pl seqMerger.pl \
	generateGenBankMail.pl importChado.pl

check:	$(SRC) 
	for I in $?; do ( perl -c $$I --installdeps); done
	touch check

# 'make install' should be invoked from a higher level makefile or
# the variable INSTALLDIR should be defined

install: check
	for I in $(SRC); do (/bin/sed -e '1s:-I\.\.:-I$(INSTALLDIR):' $$I > $(INSTALLDIR)/scripts/$$I ; chmod +x $(INSTALLDIR)/scripts/$$I ); done


