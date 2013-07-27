
# a simple makefile for traversing the directory path and checking
# and installing scripts and modules

INSTALLDIR = /data/pelement
WEBINSTALLDIR = /srv/www/cgi-bin/pelement
HTMLINSTALLDIR = /srv/www/htdocs/pelement
CPANM_CONFIG = --sudo,--notest,--mirror,/share/cpan,--mirror,http://www.cpan.org

SHELL = /bin/bash -e
SRCDIR = $(dir $(lastword $(MAKEFILE_LIST)))

PERL_SCRIPTS = $(shell cd "$(SRCDIR)" && find perl -name '*.pl')
PERL_CGI = $(shell cd "$(SRCDIR)" && find cgi -name '*.pl')
PERL_MODULES = $(shell cd "$(SRCDIR)" && find modules -name '*.pm')
JAVASCRIPT = $(shell cd "$(SRCDIR)" && find html -name '*.js')
IMAGES = $(shell cd "$(SRCDIR)" && find html -name '*.png' -o -name '*.xpm')
CSS = $(shell cd "$(SRCDIR)" && find html -name '*.css')

check: scriptcheck cgicheck

scriptcheck: modulecheck
	@cd "$(SRCDIR)" && \
	for I in $(PERL_SCRIPTS); do test -e .scriptcheck -a .scriptcheck -nt "$$I" || perl -MFile::Spec -Mlib::xi="$(CPANM_CONFIG)" -c "$$I"; done
	@cd "$(SRCDIR)" && touch .scriptcheck

cgicheck: modulecheck
	@cd "$(SRCDIR)" && \
	for I in $(PERL_CGI); do test -e .cgicheck -a .cgicheck -nt "$$I" || perl -MFile::Spec -Mlib::xi="$(CPANM_CONFIG)" -c "$$I"; done
	@cd "$(SRCDIR)" && touch .cgicheck

modulecheck:
	@cd "$(SRCDIR)" && \
	for I in $(PERL_MODULES); do test -e .modulecheck -a .modulecheck -nt "$$I" || perl -MFile::Spec -Mlib::xi="$(CPANM_CONFIG)" -Imodules -c "$$I"; done
	@cd "$(SRCDIR)" && touch .modulecheck

webinstall: cgiinstall htmlinstall jsinstall
cgiinstall: cgicheck
	@test "$(WEBINSTALLDIR)" != ""
	@cd "$(SRCDIR)" && \
	for I in $(PERL_CGI) ; do mkdir -p "$(WEBINSTALLDIR)" && cp -v "$$I" "$(WEBINSTALLDIR)"; done && \
	for I in $(PERL_MODULES) ; do mkdir -p "$(WEBINSTALLDIR)/$$(dirname "$$I")" && cp -v "$$I" "$(WEBINSTALLDIR)/$$I"; done
jsinstall:
	@test "$(HTMLINSTALLDIR)" != ""
	@cd "$(SRCDIR)" && \
	for I in $(JAVASCRIPT) ; do mkdir -p "$(HTMLINSTALLDIR)" && cp -v "$$I" "$(HTMLINSTALLDIR)"; done
htmlinstall:
	@test "$(HTMLINSTALLDIR)" != ""
	@cd "$(SRCDIR)" && \
	for I in $(IMAGES) ; do mkdir -p "$(HTMLINSTALLDIR)/images" && cp -v "$$I" "$(HTMLINSTALLDIR)/images"; done && \
	for I in $(CSS) ; do mkdir -p "$(HTMLINSTALLDIR)" && cp -v "$$I" "$(HTMLINSTALLDIR)"; done

install: scriptcheck
	@test "$(INSTALLDIR)" != ""
	@cd "$(SRCDIR)" && \
	for I in $(PERL_SCRIPTS) ; do mkdir -p "$(INSTALLDIR)/scripts" && cp -v "$$I" "$(INSTALLDIR)/scripts"; done && \
	for I in $(PERL_MODULES) ; do mkdir -p "$(INSTALLDIR)/$$(dirname "$$I")" && cp -v "$$I" "$(INSTALLDIR)/$$I"; done

