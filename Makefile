# Make SOAP distribution.
#
# @(#)$Id: Makefile,v 1.2 2001/03/17 02:11:27 pat Exp pat $

dist:
	tar -c -z -v -C .. -f ../TclSOAP-1.3.tar.gz \
		--exclude=soap1.3/RCS \
		--exclude=soap1.3/doc/RCS \
		--exclude=soap1.3/tests/RCS \
		--exclude=soap1.3/tmp \
		--exclude=soap1.3/Makefile \
		soap1.3

.PHONY: dist