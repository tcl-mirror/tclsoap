# soap-tests.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Create some remote SOAP access methods to demo servers.
#
# The SOAP::Lite project has some nice examples of object access that
# we should pursue
# 
# @(#)$Id$

package require SOAP 1.0


SOAP::create getTemp \
	-uri "urn:xmethods-Temperature" \
	-proxy "http://services.xmethods.net/soap/servlet/rpcrouter" \
	-params { "zipcode" "string" }

SOAP::create pingHost \
	-proxy "http://services.xmethods.net:80/perl/soaplite.cgi" \
	-uri "urn:xmethodsSoapPing" \
	-params { "hostname" "string" }

SOAP::create hi \
	-uri "http://www.soaplite.com/Demo" \
	-proxy "http://services.soaplite.com/hibye.cgi" \
	-params {}

SOAP::create languages \
	-uri "http://www.soaplite.com/Demo" \
	-proxy "http://services.soaplite.com/hibye.cgi" \
	-params {}

SOAP::create f2c \
	-uri "http://www.soaplite.com/Temperatures" \
	-proxy "http://services.soaplite.com/temper.cgi" \
	-params { "temp" "float"}\
	-alias F2C

SOAP::create c2f \
	-uri "http://www.soaplite.com/Temperatures" \
	-proxy "http://services.soaplite.com/temper.cgi" \
	-params { "temp" "float"}\
	-alias C2F

SOAP::create c2f_broke \
	-uri "http://www.soaplite.com/Temperatures" \
	-proxy "http://services.soaplite.com/temper.cgi" \
	-params { "temp" "float"}\
	-alias C2F_broke

SOAP::create NextGUID \
	-uri "http://www.itfinity.net/soap/guid/guid.xsd" \
	-proxy "http://www.itfinity.net/soap/guid/default.asp" \
	-params {}

SOAP::create checkDomain \
	-uri "urn:xmethods-DomainChecker" \
	-proxy "http://services.xmethods.net:9090/soap" \
	-params { "domainname" "string" }

SOAP::create whois \
	-uri "http://www.pocketsoap.com/whois" \
	-proxy "http://www.razorsoft.net/ssss4c/whois.asp" \
	-params { "name" "string" }

