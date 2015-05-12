# BDGP Pelement Insertion Data Tracking DB

The goal of the Drosophila gene disruption project (GDP) is to create a public collection of mutant strains of Drosophila melanogaster containing single transposon insertions associated with each gene.  Over the course of the project, P-element, piggyBac, and Minos transposons have been used, to take advantage of differences in their target site specificities.  **This database tracks information used to characterize each insertion.**

This project is a collaboration among the laboratories of Hugo Bellen (Baylor College of Medicine), Roger Hoskins (Lawrence Berkeley National Laboratory) and Allan Spradling (Carnegie Institution of Washington) and is supported by the National Institutes of Health (5R01GM067858)and the Howard Hughes Medical Institute. 

### Authors

- Benjamin W Booth [2012-2015]
- Joseph W Carlson [200?-2012]

### Links

http://flypush.imgen.bcm.tmc.edu/pscreen/about.html

### Publications

- Nagarkar-Jaiswal, et al., 2015 Elife [pmid 25824290]
- Venken, et al., 2011 Nat Methods [pmid 21985007]
- Spradling, Bellen, and Hoskins, 2011 PNAS [pmid 21896744]
- Bellen, et al., 2011 Genetics [pmid 21515576]
- Buszczak, et al., 2007 Genetics [pmid 17194782]
- Bellen, et al., 2004 Genetics [pmid 15238527]
- Spradling, et al., 1999 Genetics [pmid 10471706]
- Spradling, et al., 1995 PNAS [pmid 7479892]

### Installation

Tested on Ubuntu 14.04

- apt-get install apache2 ncbi-blast+ postgresql-9.3 libpq-dev libgd-dev
- perlbrew install perl-5.20.2
- cpanm lib::xi DBD::Pg
- a2enmod cgid

### Useful files and directories

- http://gdp.example.com/cgi-bin/pelement/pelement.pl
- /data/pelement/modules/Pelement.pm
- /data/pelement/trace
- /data/pelement/log
- /var/log/apache2/error.log
