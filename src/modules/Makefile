SRC =   Alignment.pm Lane.pm AlignmentSet.pm LaneSet.pm Association.pm \
	Ligation.pm Batch.pm LigationSet.pm BlastInterface.pm PCommon.pm \
	Blast_HSP.pm Pelement.pm Blast_Hit.pm PelementCGI.pm Blast_Report.pm \
	PelementDBI.pm Blast_ReportSet.pm PhredInterface.pm Blast_Run.pm \
	Phred_Qual.pm DbObject.pm Phred_Seq.pm DbObjectSet.pm Sample.pm SampleSet.pm\
	Digestion.pm Seq.pm DigestionSet.pm SeqSet.pm Files.pm Seq_Alignment.pm \
	Gadfly_Syn.pm Seq_AlignmentSet.pm Gel.pm Sequence.pm GelSet.pm Session.pm \
	GenBankScaffold.pm Strain.pm IPCR.pm WebSession.pm IPCRSet.pm Seq_Assembly.pm


install: check
	for I in $(SRC); do ( cp $$I $(INSTALLDIR)/modules ); done


check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check
