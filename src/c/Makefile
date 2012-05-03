
fasta_extract.so:	fasta_extract.c fasta_extract.i
	swig -perl5 -exportall fasta_extract.i
	gcc -fpic -c fasta_extract_wrap.c -I /usr/local/lib/perl5/5.6.1/sun4-solaris/CORE -I .
	gcc -fpic -c fasta_extract.c -I ./
	gcc -shared fasta_extract*.o -o fasta_extract.so

install:	fasta_extract.pm fasta_extract.so
	cp fasta_extract.pm /usr/local/bdgp/lib/perl/
	cp fasta_extract.so /usr/local/bdgp/lib/perl/sun4-solaris/auto/fasta_extract/

