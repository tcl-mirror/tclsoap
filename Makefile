# Make SOAP distribution.
#
# @(#)$Id$

dist:
	tar -c -z -v -C .. -f ../TclSOAP-1.2.tar.gz \
		--exclude=soap1.2/RCS \
		--exclude=soap1.2/samples \
		--exclude=soap1.2/doc/RCS \
		--exclude=soap1.2/tests/RCS \
		--exclude=soap1.2/Makefile \
		soap1.2

.PHONY: dist