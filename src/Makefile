
# a simple makefile for traversing the directory path and checking
# and installing scripts and modules

INSTALLDIR = /data/pelement
WEBINSTALLDIR = /opt/httpd/cgi-bin/pelement

check:
	for I in perl cgi modules ; do (cd $$I; make check ); done

all:
	for I in perl cgi modules ; do (cd $$I; make all ); done

webinstall: hostcheck
	for I in cgi modules ; do (cd $$I; INSTALLDIR=$(WEBINSTALLDIR) make install ); done
	
install:
	for I in perl modules ; do (cd $$I; INSTALLDIR=$(INSTALLDIR) make install ); done

hostcheck:
	hostname | grep boss 
