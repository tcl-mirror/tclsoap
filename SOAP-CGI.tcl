# SOAP-CGI.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# A CGI framework for SOAP and XML-RPC services from TclSOAP
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#

package provide SOAP::CGI 1.0

namespace eval SOAP {
    namespace eval CGI {

	# -----------------------------------------------------------------
	# Configuration Parameters
	# -----------------------------------------------------------------
	#   soapdir   - the directory searched for SOAP methods
	#   xmlrpcdir - the directory searched for XML-RPC methods
	#   logfile   - a file to update with usage data. 
	#
	#   This framework is such that the same tcl procedure can be called 
	#   for both types of request. The result will be approprately packaged.
	#   So these variables can point to the _same_ directory.
	
	variable soapdir   "soap"
	variable xmlrpcdir $soapdir
	variable logfile   "rpc.log"
	
	# -----------------------------------------------------------------

	variable rcsid {$Id$}
	variable methodName {}
	
	package require dom
	package require SOAP
	package require SOAP::Utils
	catch {namespace import -force [namespace parent]::Utils::*}

	namespace export log main
    }
}

# -------------------------------------------------------------------------

# Description:
#   Maintain a basic call log so that we can monitor for errors and 
#   popularity.
# Notes:
#   This file will need to be writable by the httpd user. This is usually
#   'nobody' on unix systems, so the logfile will need to be world writeable.
#
proc SOAP::CGI::log {protocol action result} {
    variable logfile
    catch {
	if {[info exists logfile] && $logfile != {} && [file writable $logfile]} {
	    set stamp [clock format [clock seconds] \
		    -format {%Y%m%dT%H%M%S} -gmt true]
	    set f [open $logfile "a+"]
	    puts $f [list $stamp $protocol $action $result \
		    $::env(REMOTE_ADDR) $::env(HTTP_USER_AGENT)]
	    close $f
	}
    }
}

# -------------------------------------------------------------------------

# Description:
#   Write a complete html page to stdout, setting the content length correctly.
# Notes:
#   The string length is incremented by the number of newlines as HTTP content
#   assumes CR-NL line endings.
#
proc write {html {type text/html}} {
    puts "Content-Type: $type"
    set len [string length $html]
    puts "X-Content-Length: $len"
    incr len [regexp -all "\n" $html]
    puts "Content-Length: $len"

    puts "\n$html"
    catch {flush stdout}
}

# -------------------------------------------------------------------------

# Description:
#   Handle incoming XML-RPC requests.
#   We extract the name of the method and the arguments and search for
#   the implementation in $::xmlrpcdir. This is then evaluated and the result
#   is wrapped up and returned or a fault packet is generated.
# Parameters:
#   doc - a DOM tree constructed from the input request XML data.
#
proc SOAP::CGI::xmlrpc_call {doc} {
    variable xmlrpcdir
    variable methodName
    package require XMLRPC::Domain
    if {[catch {
	
	set methodNode [selectNode $doc "/methodCall/methodName"]
	set methodName [getElementValue $methodNode]

	set paramsNode [selectNode $doc "/methodCall/params"]
	if {[catch {getElementValues $paramsNode} argValues]} {
	    set argValues {}
	}
	catch {dom::DOMImplementation destroy $doc}

	# load in the required method
	if {[catch {source [file join $xmlrpcdir $methodName]}]} {
	    error "unknown method name: \"$methodName\" was not found"
	}
	
	# evaluate the method
	set msg [interp eval {} [list $methodName] $argValues]

	# generate a reply using the XMLRPC::Domain code
	set reply [XMLRPC::Domain::reply_simple \
		[dom::DOMImplementation create] \
		{urn:xmlrpc-cgi} "${methodName}Response" $msg]
	set xml [dom::DOMImplementation serialize $reply]
	regsub "<!DOCTYPE\[^>\]+>\n" $xml {} xml
	catch {dom::DOMImplementation destroy $reply}

    } msg]} {
	set detail [list "errorCode" $::errorCode "stackTrace" $::errorInfo]
	set xml [XMLRPC::Domain::fault 500 "$msg" $detail]
	error $xml {} XMLRPC
    }

    # publish the answer
    return $xml
}

# -------------------------------------------------------------------------

# Description:
#   Handle incoming SOAP requests.
#   We extract the name of the SOAP method and the arguments and search for
#   the implementation in $::soapdir. This is then evaluated and the result
#   is wrapped up and returned or a SOAP Fault is generated.
# Parameters:
#   doc - a DOM tree constructed from the input request XML data.
#
proc SOAP::CGI::soap_call {doc} {
    variable soapdir
    variable methodName
    package require SOAP::Domain
    if {[catch {

	# Get the method name from the XML request.
	set methodNode [selectNode $doc "/Envelope/Body/*"]
	set methodName [dom::node cget $methodNode -nodeName]

	# Get the XML namespace for this method.
	set methodNamespace [array get \
		[dom::node cget $methodNode -attributes]]
	set nsindex [lsearch -regexp $methodNamespace {http://.*/xmlns}]
	if {$nsindex != -1} {
	    set methodNamespace [lindex $methodNamespace [expr $nsindex + 1]]
	} else {
	    set methodNamespace {}
	}

	# Extract the parameters.
	set argNodes [selectNode $doc "/Envelope/Body/*/*"]
	set argValues {}
	foreach node $argNodes {
	    lappend argValues [decomposeSoap $node]
	}
	catch {dom::DOMImplementation destroy $doc}

	# Load the SOAP implementation files at global level.
	# Once this only loaded the file required, but to do this with 
	# namespaces as well needs a map as we can't use the namespace name
	# as a filename (generally)
	foreach file [glob $soapdir/*] {
	    namespace eval :: "source [list $file]"
	}
	
	# find the implementation by looking in the XML namespace, then
	# by looking at the global level.
	set fqdn "${methodNamespace}::${methodName}"
	if {[catch {interp eval {} namespace origin $fqdn} fqdn]} {
	    if {[catch {interp eval {} namespace origin "::$methodName"} fqdn]} {
		error "Invalid SOAP request: method \"${methodNamespace}::${methodName}\" not found"
	    }
	}

	# evaluate the method
	set msg [interp eval {} [list $fqdn] $argValues]

	# generate a reply using the SOAP::Domain code
	set reply [SOAP::Domain::reply_simple \
		[dom::DOMImplementation create] \
		$methodNamespace "${methodName}Response" $msg]
	set xml [dom::DOMImplementation serialize $reply]
	regsub "<!DOCTYPE\[^>\]+>\n" $xml {} xml
	catch {dom::DOMImplementation destroy $reply}
	
    } msg]} {
	# Handle errors the SOAP way.
	#
	set detail [list "errorCode" $::errorCode "stackTrace" $::errorInfo]
	if {[lindex $detail 1] == "CLIENT"} {
	    set code "SOAP-ENV:Client"
	} else {
	    set code "SOAP-ENV:Server"
	}
	set xml [SOAP::Domain::fault $code "$msg" $detail]
	error $xml {} SOAP
    }

    # publish the answer
    return $xml
}

# -------------------------------------------------------------------------

# Description:
#    Examine the incoming data and decide which protocol handler to call.
#    Everything is evaluated in a large catch. If any errors are thrown we
#    will wrap them up in a suitable reply. At this stage we return
#    HTML for errors.
# Parameters:
#    xml - for testing purposes we can source this file and provide XML
#          as this parameter. Normally this will not be used.
#
proc SOAP::CGI::main {{xml {}}} {
    catch {package require tcllib} ;# re-eval the pkgIndex
    package require ncgi
    variable methodName

    if { [catch {
	
	# -------------------------------------------------------------------
	
	# Get the POSTed XML data and parse into a DOM tree.
	if {$xml == {}} {
	    set xml [ncgi::query]
	}
	set doc [dom::DOMImplementation parse $xml]
	
	# Identify the type of request - SOAP or XML-RPC
	if {[selectNode $doc "/Envelope"] != {}} {
	    set result [soap_call $doc]
	    log "SOAP" $methodName "ok"
	} elseif {[selectNode $doc "/methodCall"] != {}} {
	    set result [xmlrpc_call $doc]
	    log "XMLRPC" $methodName "ok"
	} else {
	    dom::DOMImplementation destroy $doc
	    error "invalid protocol: the XML data is neither SOAP not XML-RPC"
	}

	# Send the answer to the caller
	write $result text/xml

    } msg]} {
	
	# if the error was thrown from either of the protocol
	# handlers then the error code is set to indicate that the
	# message is a properly encoded SOAP/XMLRPC Fault.
	# If its a CGI problem, then be a CGI error.
	switch -- $::errorCode {
	    SOAP   {
		write $msg
		catch {
		    set doc [dom::DOMImplementation parse $msg]
		    set r [decomposeSoap [selectNode $doc /Envelope/Body/*]]
		} msg
		log "SOAP" [list $methodName $msg] "error" 
	    }
	    XMLRPC {
		write $msg
		catch {
		    set doc [dom::DOMImplementation parse $msg]
		    set r [getElementNamedValues [selectNode $doc \
			    /methodResponse/*]]
		} msg
		log "XMLRPC" [list $methodName $msg] "error" 
	    }
	    default {
		variable rcsid

		set html "<!doctype HTML public \"-//W3O//DTD W3 HTML 2.0//EN\">\n"
		append html "<html>\n<head>\n<title>CGI Error</title>\n</head>\n<body>"
		append html "<h1>CGI Error</h1>\n<p>$msg</p>\n"
		append html "<br>\n<pre>$::errorInfo</pre>\n"
		append html "<p><font size=\"-1\">$rcsid</font></p>"
		append html "</body>\n</html>"
		write $html
		
		log "unknown" [string range $xml 0 60] "error"
	    }
	}
    }
}

# -------------------------------------------------------------------------
#
# Local variables:
# mode: tcl
# End:
