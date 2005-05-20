SRC =	Alignment.pm AlignmentSet.pm Association.pm Batch.pm BlastInterface.pm \
	Blast_HSP.pm Blast_Hit.pm Blast_Report.pm Blast_ReportSet.pm \
	Blast_Run.pm Blast_RunSet.pm Collection_Protocol.pm Cytology.pm \
	DbObject.pm DbObjectSet.pm Digestion.pm DigestionSet.pm Enzyme.pm \
	Files.pm FlyBase_Submission_Info.pm Gadfly_Syn.pm Gel.pm GelSet.pm \
	GenBankScaffold.pm GenBank_Submission_Info.pm Gene_Association.pm \
	Gene_AssociationSet.pm IPCR.pm IPCRSet.pm Lane.pm LaneSet.pm \
	Ligation.pm LigationSet.pm PCommon.pm Pelement.pm PelementCGI.pm \
	PelementDBI.pm Phenotype.pm PhrapInterface.pm PhredInterface.pm \
	Phred_Qual.pm Phred_Seq.pm Primer.pm Processing.pm Sample.pm \
	SampleSet.pm Seq.pm SeqSet.pm Seq_Alignment.pm Seq_AlignmentSet.pm \
	Seq_Assembly.pm Seq_AssemblySet.pm Sequence.pm Session.pm Stock_Record.pm \
	Stock_RecordSet.pm Strain.pm Submitted_Seq.pm Trimming_Protocol.pm \
	Vector.pm WebCache.pm WebSession.pm Strain_Alias.pm fasta_extract.pm

install: check
	for I in $(SRC); do ( cp $$I $(INSTALLDIR)/modules ); done
	cp fasta_extract.so $(INSTALLDIR)/modules


check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check
