# Make SOAP distribution.
#
# @(#)$Id: Makefile,v 1.4 2001/04/22 22:16:57 pat Exp $

tag:
	rcs -nsoap1_3: RCS/* doc/RCS/* tests/RCS/* samples/RCS/* 


# Use cvs export now. Ensures that you have tagged the source with a 
# symbolic version number.
dist: pkgIndex
	tar -c -z -v -C .. -f ../TclSOAP-1.3.tar.gz \
		--exclude=tclsoap/CVS \
		--exclude=tclsoap/doc/CVS \
		--exclude=tclsoap/tests/CVS \
		--exclude=tclsoap/samples/CVS \
		--exclude=tclsoap/tmp \
		--exclude=tclsoap/Makefile \
		tclsoap

pkgIndex:
	echo 'pkg_mkIndex -verbose .' | tclsh

.PHONY: dist
.PHONY: pkgIndex
.PHONY: tag