# tclserver.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide webservices from tclhttpd using the SOAP::CGI package.
# This is equivalent to the `rpc' script in cgi-bin that provides the same
# webservices via CGI.
#
# $Id$

package require SOAP::CGI
set root "/users/pat/lib/tcl/tclsoap/cgi-bin"
set SOAP::CGI::soapdir       [file join $root soap]
set SOAP::CGI::soapmapfile   [file join $root soapmap.dat]
set SOAP::CGI::xmlrpcdir     [file join $root soap]
set SOAP::CGI::xmlrpcmapfile [file join $root xmlrpcmap.dat]
set SOAP::CGI::logfile       "../logs/rpc.log"

Url_PrefixInstall /RPC rpc_handler

proc rpc_handler {sock args} {
    upvar \#0 Httpd$sock data
    
    set query $data(query)
    set doc [dom::DOMImplementation parse $query]

    if {[SOAP::CGI::selectNode $doc "/Envelope"] != {}} {
	set result [SOAP::CGI::soap_invocation $doc]
    } elseif {[SOAP::CGI::selectNode $doc "/methodCall"] != {}} {
	set result [SOAP::CGI::xmlrpc_invocation $doc]
    }
    # Hmmm. Errors should be 500 not 200.
    Httpd_ReturnData $sock text/xml $result 200
}
