SRC =	Alignment.pm AlignmentSet.pm Association.pm Batch.pm BatchSet.pm \
	BlastInterface.pm Blast_HSP.pm Blast_HSPSet.pm Blast_Hit.pm \
	Blast_HitSet.pm Blast_Option.pm Blast_OptionSet.pm \
	Blast_Report.pm Blast_ReportSet.pm Blast_Run.pm \
	Blast_RunSet.pm Collection_Protocol.pm Cytology.pm DbObject.pm \
	DbObjectSet.pm Digestion.pm DigestionSet.pm Enzyme.pm Files.pm \
	FlyBase_Submission_Info.pm Gadfly_Syn.pm Gel.pm GelSet.pm \
	GenBankScaffold.pm GenBank_Submission_Info.pm Gene_Association.pm \
	Gene_AssociationSet.pm IPCR.pm IPCRSet.pm Lane.pm LaneSet.pm \
	Ligation.pm LigationSet.pm PCommon.pm Pelement.pm \
	PelementCGI.pm PelementDBI.pm Phenotype.pm PhrapInterface.pm \
	PhredInterface.pm Phred_Qual.pm Phred_Seq.pm Primer.pm \
	Processing.pm Sample.pm SampleSet.pm Seq.pm SeqSet.pm \
	Seq_Alignment.pm Seq_AlignmentSet.pm Seq_Assembly.pm \
	Seq_AssemblySet.pm Sequence.pm Session.pm Stock_Record.pm \
	Stock_RecordSet.pm Strain.pm Strain_Alias.pm Submitted_Seq.pm \
	Trimming_Protocol.pm Vector.pm WebCache.pm WebSession.pm \
        SQLObject.pm SQLObjectSet.pm ChadoGeneModelSet.pm GeneModelSet.pm \
	Phase.pm PhaseSet.pm StrainSet.pm \
 	RegionImage.pm GeneralUtils/Structures.pm \
 	GeneralUtils/XML/Generator.pm NCBIBlastInterface.pm

install: check
	for I in $(SRC); do ( cp --remove-destination --parents $$I $(INSTALLDIR)/modules ); done

check:	$(SRC) 
	for I in $?; do ( perl -c $$I --installdeps); done
	touch check


