
# a simple makefile for traversing the directory path and checking
# and installing scripts and modules

INSTALLDIR = /data/pelement
SEDINSTALLDIR = \\/data\\/pelement
WEBINSTALLDIR = /www/weasel_94/cgi-bin/pelement

check:
	for I in perl cgi modules ; do (cd $$I; make check ); done

all:
	for I in perl cgi modules ; do (cd $$I; make all ); done

webinstall:
	for I in cgi modules ; do (cd $$I; INSTALLDIR=$(WEBINSTALLDIR) make install ); done
	
install:
	for I in perl modules ; do (cd $$I; INSTALLDIR=$(INSTALLDIR) SEDINSTALLDIR=$(SEDINSTALLDIR) make install ); done
