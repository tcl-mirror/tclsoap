# SOAP.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Provide Tcl access to SOAP methods.
#

## Needs testing using SOAP::Lite's services esp. the object access demo.
## Add transport configure command to cope with SMTP/HTTP/FTP... and to
## deal with authenticating HTTP proxies.

proc basic_authorization {} {
    return "Basic UkVOSVNIQVdccHQxMTE5OTI6Y2Ruam5mZGZodQ=="
}

package provide SOAP 1.0

# -------------------------------------------------------------------------

package require http 2.3
package require dom 1.6

namespace eval SOAP {
    variable version 1.0
    variable rcs_version { $Id$ }
}

# -------------------------------------------------------------------------

# Provide easy access to the namespace variables for each method.

proc SOAP::get { methodName varName } {
    eval set r \$Commands::${methodName}::$varName
    return $r
}

# -------------------------------------------------------------------------

# Configure a SOAP method

proc SOAP::configure { methodName args } {
    set valid [catch { eval set url \$Commands::${methodName}::proxy } msg]
    if { $valid != 0 } {
	return -code error "invalid command: \"$methodName\" not defined"
    }

    if { [llength $args] == 0 } {
	set r {}
	foreach item { uri proxy params reply alias transport } {
	    set valid [ catch { set val [get $methodName $item] } msg ]
	    if { $valid != 0 } { set val {} }
	    lappend r "-$item" $val
	}
	return $r
    }

    foreach {opt value} $args {
	switch -- $opt {
	    -uri       { set Commands::${methodName}::uri $value }
	    -proxy     { set Commands::${methodName}::proxy $value }
	    -params    { set Commands::${methodName}::params $value }
	    -reply     { set Commands::${methodName}::reply $value }
	    -transport { set Commands::${methodName}::transport $value }
	    -alias     { set Commands::${methodName}::alias $value }
	    default {
		return -code error "unknown option \"$opt\""
	    }
	}
    }

    if { [get $methodName alias] == {} } { 
	set Commands::${methodName}::alias $methodName
    }

    if { [get $methodName transport] == {} } {
	set Commands::${methodName}::transport transport_http
    } 

    proc Commands::${methodName}::xml {methodName args} {
	variable uri ; variable params ; variable reply

	if { [llength $args] != [expr [llength $params] / 2]} {
	    set msg "wrong # args: should be \"$methodName"
	    foreach { name type } $params {
		append msg " " $name
	    }
	    append msg "\""
	    return -code error $msg
	}
	set doc [dom::DOMImplementation create]
	set envx [dom::document createElement $doc "SOAP-ENV:Envelope"]
	dom::element setAttribute $envx \
		"xmlns:SOAP-ENV" "http://schemas.xmlsoap.org/soap/envelope/"
	dom::element setAttribute $envx \
		"xmlns:xsi"      "http://www.w3.org/1999/XMLSchema-instance"
	dom::element setAttribute $envx \
		"xmlns:xsd"      "http://www.w3.org/1999/XMLSchema"
	dom::element setAttribute $envx "SOAP-ENV:encodingStyle" \
		"http://schemas.xmlsoap.org/soap/encoding/"
	set bod [dom::document createElement $envx "SOAP-ENV:Body"]
	set cmd [dom::document createElement $bod "ns:$methodName" ]
	dom::element setAttribute $cmd "xmlns:ns" $uri
	
	set param 0
	foreach {name type} $params {
	    set par [dom::document createElement $cmd $name]
	    dom::element setAttribute $par "xsi:type" "xsd:$type"
	    dom::document createTextNode $par [lindex $args $param]
	    incr param
	}
	return $doc ;# return the DOM object
    }

    # create a command in the global namespace.
    proc ::[get $methodName alias] { args } \
	    "eval SOAP::invoke $methodName \$args"

    return [namespace which ::[get $methodName alias]]
}

# -------------------------------------------------------------------------

proc SOAP::create { args } {
    if { [llength $args] < 1 } {
	return -code error \
		"wrong # args: should be \"create methodName ?options?\""
    } else {
	set methodName [lindex $args 0]
	set args [lreplace $args 0 0]
    }

    # Create a namespace to hold the variables for this command.
    namespace eval Commands::$methodName {
	variable uri       {} ;# the XML namespace URI for this method 
	variable proxy     {} ;# URL for the location of a provider
	variable params    {} ;# list of name type pairs for the parameters
	variable reply     {} ;# the type of the reply (string, integer ...)
	variable transport {} ;# the transport procedure for this method
	variable alias     {} ;# Tcl command name for this method
    }

    return [eval "configure $methodName $args"]
}

# -------------------------------------------------------------------------

# Perform a SOAP method using the configured transport.

proc SOAP::invoke { methodName args } {
    set valid [catch { set url [get $methodName proxy] } msg]
    if { $valid != 0 } {
	return -code error "invalid command: \"$methodName\" not defined"
    }
 
    set doc [eval "Commands::${methodName}::xml $methodName $args"]
    set trn [get $methodName transport]

    set reply [$trn $url [dom::DOMImplementation serialize $doc] ]

    set dom [dom::DOMImplementation parse $reply]
    
    return $reply
}

# -------------------------------------------------------------------------

# HTTP transport expects a url, the SOAP data and optionally a proxy HTTP
# server eg: http://www.scriptics.org/ $soap webproxy:8080

proc SOAP::transport_http { url request {proxy {}} } {
    set headers {}

    # setup the HTTP POST request
    ::http::config -useragent "TclSOAP 1.0"
    if { $proxy != {} } {
	set headers [list "Proxy-Authorization" [basic_authorization]]
	set proxy [split $proxy ":"]
	::http::config -proxyhost [lindex $proxy 0]\
		-proxyport [lindex $proxy 1]
    }

    # POST and get the reply.
    set reply [ ::http::geturl $url -headers $headers \
	    -type text/xml -query $request ]

    if { [::http::status $reply] != "ok" || [::http::ncode $reply ] != 200 } {
	return -code error \
		"SOAP transport error: \"[::http::code $reply] ($reply)\""
    }

    return [::http::data $reply]
}

# -------------------------------------------------------------------------

proc SOAP::transport_print { url soap {proxy {}} } {
    puts "$soap"
}

# -------------------------------------------------------------------------