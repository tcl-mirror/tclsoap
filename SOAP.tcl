# SOAP.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Provide Tcl access to SOAP 1.1 methods.
#

# Todo:
# - Need to do fault processing for SOAP 1.1
# - Needs testing using SOAP::Lite's services esp. the object access demo.
# - Clean up the http connections. Keep the last one for state and error 
#   info but delete during the next call.

package provide SOAP 1.0

# -------------------------------------------------------------------------

package require http 2.3
package require dom 1.6

namespace eval SOAP {
    variable version 1.0
    variable rcs_version { $Id: SOAP.tcl,v 1.2 2001/02/19 00:44:46 pat Exp pt111992 $ }
}

# -------------------------------------------------------------------------

# Provide easy access to the namespace variables for each method.

proc SOAP::get { nameSpace varName } {
    set ok [ catch { eval set r \$${nameSpace}::${varName} } ]
    if { $ok != 0 } {
        set r {}
    }
    return $r
}

proc SOAP::get2 { nameSpace varName } {
    eval set r \$${nameSpace}::${varName}
    return $r
}

# -------------------------------------------------------------------------

# Configure a SOAP method

proc SOAP::configure { methodName args } {

    if { $methodName == "-transport" } {
        return [eval "transport_configure $args"]
    }

    set valid [catch { eval set url \$Commands::${methodName}::proxy } msg]
    if { $valid != 0 } {
        return -code error "invalid command: \"$methodName\" not defined"
    }

    if { [llength $args] == 0 } {
        set r {}
        foreach item { uri proxy params reply alias transport action } {
            set val [get Commands::$methodName $item]
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
            -action    { set Commands::${methodName}::action $value }
            default {
                return -code error "unknown option \"$opt\""
            }
        }
    }

    if { [get Commands::$methodName alias] == {} } { 
        set Commands::${methodName}::alias $methodName
    }

    if { [get Commands::$methodName transport] == {} } {
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

    # create a command in the callers namespace.
    uplevel 2 "proc [get Commands::$methodName alias] { args } {eval [namespace current]::invoke $methodName \$args}"

    # return the fully qualified command created.
    return [uplevel 2 "namespace which [get Commands::$methodName alias]"]
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
        variable action    {} ;# Contents of the SOAPAction header
    }

    return [eval "configure $methodName $args"]
}

# -------------------------------------------------------------------------

# Perform a SOAP method using the configured transport.

proc SOAP::invoke { methodName args } {
    set valid [catch { set url [get2 Commands::$methodName proxy] } msg]
    if { $valid != 0 } {
        return -code error "invalid command: \"$methodName\" not defined"
    }
    
    # Get the DOM object containing our request
    # We have to strip out the DOCTYPE element though. It would be better to
    # remove the DOM element, but that didn't work.
    set doc [eval "Commands::${methodName}::xml $methodName $args"]
    set prereq [dom::DOMImplementation serialize $doc]
    set req {}
    dom::DOMImplementation destroy $doc
    regsub {<!DOCTYPE[^>]*>\n} $prereq {} req

    # Send the SOAP packet using the configured transport.
    set transport [ get Commands::$methodName transport ]
    set reply [ $transport $methodName $url $req ]

    # Parse the SOAP reply. ---- DO FAULT PROCESSING HERE ----
    #set dom [dom::DOMImplementation parse $reply]
    package require SOAP::Parse
    set not_dom [SOAP::Parse::parse $reply]
    
    return $not_dom
}

# -------------------------------------------------------------------------

# Check SOAP packet and return error if it is a SOAP fault.

proc SOAP::check_fault { doc } {
    set env [dom::document cget $doc -documentElement]
    set bod [dom::document getElementsByTagName $env {SOAP-ENV:Body}]
    set flt [dom::document getElementsByTagName $bod {SOAP-ENV:Fault}]
    return -code error $flt
}

# -------------------------------------------------------------------------

# HTTP transport expects a url and the SOAP data.
# If you need to use a proxy or have some other configuration then you must
# setup the http package independently eg:
#  ::http::config -proxyhost wwwproxy

proc SOAP::transport_http { methodName url request } {
    variable version

    # setup the HTTP POST request
    ::http::config -useragent "TclSOAP $version"

    # If a proxy was configured, use it.
    set proxy [get Transport::http proxy]

    if { $proxy != {} } {
        set proxy [split $proxy ":"]
        ::http::config -proxyhost [lindex $proxy 0]\
                -proxyport [lindex $proxy 1]
    }
    
    # There may be http headers configured. eg: for proxy servers
    # eg: SOAP::configure -transport http -headers 
    #    [list "Proxy-Authorization" [basic_authorization]]
    set headers [get Transport::http headers]

    # Add mandatory SOAPAction header (SOAP 1.1). This may be empty
    lappend headers "SOAPAction" [get Commands::$methodName action]

    # POST and get the reply.
    set reply [ ::http::geturl $url -headers $headers \
            -type text/xml -query $request ]

    if { [::http::status $reply] != "ok" || [::http::ncode $reply ] != 200 } {
        return -code error \
                "SOAP transport error: \"[::http::code $reply] ($reply)\""
    }

    set r [::http::data $reply]
    ::http::cleanup $reply
    return $r
}

# -------------------------------------------------------------------------

# A dummy SOAP transport procedure to examine the SOAP requests generated.

proc SOAP::transport_print { methodName url soap } {
    puts "$soap"
    return {}
}

# -------------------------------------------------------------------------

proc SOAP::transport_configure { transport args } {
    switch -- $transport {
        http {
            if { $args == {} } {
                set r {}
                foreach opt { proxy headers } {
                    lappend r "-$opt" [get Transport::${transport} $opt]
                }
                return $r
            }

            foreach { opt value } $args {
                switch -- $opt {
                    -proxy   {
                        namespace eval Transport::$transport \
                                "variable proxy $value"
                    }
                    -headers {
                        namespace eval Transport::$transport \
                                "variable headers { $value }"
                    }
                    default {
                        return -code error \
                                [concat "invalid option \"$opt\":" \
                                "must be \"-proxy host:port\" "\
                                "or \"-headers list\""]
                    }
                }
            }
        }
        print {
            return "no configuration required"
        }
        default {
            return -code error "SOAP transport \"$transport\" is undefined."
        }
    }
}

# Local variables:
#    indent-tabs-mode: nil
# End: