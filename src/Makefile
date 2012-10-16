
# a simple makefile for traversing the directory path and checking
# and installing scripts and modules

INSTALLDIR = /data/pelement
WEBINSTALLDIR = /srv/www/cgi-bin/pelement
HTMLINSTALLDIR = /srv/www/htdocs/pelement

check:
	for I in perl cgi modules ; do (cd $$I; make check ); done

all:
	for I in perl cgi modules ; do (cd $$I; make all ); done

webinstall: cgiinstall htmlinstall
	
cgiinstall: hostcheck
	for I in cgi modules ; do (cd $$I; INSTALLDIR=$(WEBINSTALLDIR) make install ); done

htmlinstall: hostcheck
	for I in html ; do (cd $$I; INSTALLDIR=$(HTMLINSTALLDIR) make install ); done
	
install:
	for I in perl modules ; do (cd $$I; INSTALLDIR=$(INSTALLDIR) make install ); done

hostcheck:
	#hostname | grep boss

dist: hostcheck
	tar czvf pelement_src.tgz `./cvsFileList.pl`
