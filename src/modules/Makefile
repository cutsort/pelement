
SRC = Alignment.pm AlignmentSet.pm Association.pm BlastInterface.pm \
	Blast_HSP.pm Blast_Hit.pm Blast_Report.pm Blast_ReportSet.pm \
	Blast_Run.pm DbObject.pm DbObjectSet.pm Files.pm Gel.pm \
	Lane.pm PCommon.pm Pelement.pm PelementCGI.pm PelementDBI.pm \
	PhredInterface.pm Seq.pm Sequence.pm Session.pm Strain.pm \
	WebSession.pm Phred_Seq.pm Phred_Qual.pm

WEBMODULES = Pelement.pm PCommon.pm WebSession.pm PelementDBI.pm Session.pm \
             PelementCGI.pm

WEBMODDIR = /www/weasel_94/cgi-bin/modules/

webinstall: $(WEBMODULES)
	for I in $?; do (cp $$I $(WEBMODDIR) ); done


check:	$(SRC) 
	for I in $?; do ( perl -c $$I ); done
	touch check


