# Make SOAP distribution.
#
# @(#)$Id: Makefile,v 1.3 2001/04/22 21:46:39 pat Exp pat $

tag:
	rcs -nsoap1_3: RCS/* doc/RCS/* tests/RCS/* samples/RCS/* 

dist:
	tar -c -z -v -C .. -f ../TclSOAP-1.3.tar.gz \
		--exclude=soap1.3/RCS \
		--exclude=soap1.3/doc/RCS \
		--exclude=soap1.3/tests/RCS \
		--exclude=soap1.3/samples/RCS \
		--exclude=soap1.3/tmp \
		--exclude=soap1.3/Makefile \
		soap1.3

.PHONY: dist