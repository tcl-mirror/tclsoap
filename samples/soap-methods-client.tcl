# Create the commands for my SOAP-domain package

package require SOAP
set methods {}

lappend methods [ SOAP::create rcsid \
	-name rcsid \
	-uri zsplat-Test \
	-proxy http://localhost:8015/soap/rcsid \
	-params {} ]

lappend methods [ SOAP::create zbase64 \
	-name base64 \
	-uri zsplat-Test \
	-proxy http://localhost:8015/soap/base64 \
	-params {msg string} ]

lappend methods [ SOAP::create ztime \
	-name time \
	-uri zsplat-Test \
	-proxy http://localhost:8015/soap/time \
	-params {} ]

lappend methods [ SOAP::create square \
	-uri zsplat-Test \
	-proxy http://localhost:8015/soap/square \
	-params {num integer} ]

lappend methods [ SOAP::create sort \
	-uri zsplat-Test \
	-proxy http://localhost:8015/soap/sort \
	-params { list string } ]

puts "$methods"
unset methods
