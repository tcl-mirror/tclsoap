# SOAP.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Provide Tcl access to SOAP 1.1 methods.
# See http://www.zsplat.freeserve.co.uk/soap1.0/doc/TclSOAP.html
# for usage details.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

# Todo:
# - Needs testing using SOAP::Lite's services esp. the object access demo.

package provide SOAP 1.2

# -------------------------------------------------------------------------

package require http 2.3

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

namespace eval SOAP {
    variable version 1.2
    variable rcs_version { $Id: SOAP.tcl,v 1.10 2001/04/10 00:22:33 pat Exp pat $ }

    namespace export create cget dump configure
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

# Retrieve configuration variables

proc SOAP::cget { args } {

    if { [llength $args] != 2 } {
        error "wrong # args: should be \"cget methodName optionName\""
    }

    set methodName [lindex $args 0]
    set optionName [lindex $args 1]

    set ok [catch {
        set r [get2 Commands::$methodName [string trimleft $optionName "-"]]
    } msg]
    if { $ok == 1 } {
        error "unknown option \"$option\""
    }
    return  $r

}

# -------------------------------------------------------------------------

# Dump the HTTP raw data from the last request performed.

proc SOAP::dump {methodName} {
    return [::http::data [cget $methodName http]]
}

# -------------------------------------------------------------------------

# Configure a SOAP method

# Should change this to work from the alias name too.
# Currently the id used in the commands namespace isn't unique. Should use
# qualified alias name as the id.

proc SOAP::configure { procName args } {

    if { $procName == "-transport" } {
        return [eval "transport_configure $args"]
    }

    set valid [catch { eval set url \$Commands::${procName}::proxy } msg]
    if { $valid != 0 } {
        error "invalid command: \"$procName\" not defined"
    }

    if { [llength $args] == 0 } {
        set r {}
        foreach item { uri proxy params reply name transport action } {
            set val [get Commands::$procName $item]
            lappend r "-$item" $val
        }
        return $r
    }

    foreach {opt value} $args {
        switch -- $opt {
            -uri       { set Commands::${procName}::uri $value }
            -proxy     { set Commands::${procName}::proxy $value }
            -params    { set Commands::${procName}::params $value }
            -reply     { set Commands::${procName}::reply $value }
            -transport { set Commands::${procName}::transport $value }
            -name      { set Commands::${procName}::name $value }
            -action    { set Commands::${procName}::action $value }
            default {
                error "unknown option \"$opt\""
            }
        }
    }

    if { [get Commands::$procName name] == {} } { 
        set Commands::${procName}::name $procName
    }

    if { [get Commands::$procName transport] == {} } {
        set Commands::${procName}::transport transport_http
    } 

    proc Commands::${procName}::xml {procName args} {
        variable uri ; variable params ; variable reply; variable name

        if { [llength $args] != [expr [llength $params] / 2]} {
            set msg "wrong # args: should be \"$procName"
            foreach { id type } $params {
                append msg " " $id
            }
            append msg "\""
            error $msg
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
        set cmd [dom::document createElement $bod "ns:$name" ]
        dom::element setAttribute $cmd "xmlns:ns" $uri

        set param 0
        foreach {key type} $params {
            set par [dom::document createElement $cmd $key]
            dom::element setAttribute $par "xsi:type" "xsd:$type"
            dom::document createTextNode $par [lindex $args $param]
            incr param
        }
        return $doc ;# return the DOM object
    }

    uplevel 1 "proc $procName { args } {eval [namespace current]::invoke $procName \$args}"

    # return the fully qualified command created.
    return [uplevel 1 "namespace which $procName"]
}

# -------------------------------------------------------------------------

proc SOAP::create { args } {
    if { [llength $args] < 1 } {
        error "wrong # args: should be \"create procName ?options?\""
    } else {
        set procName [lindex $args 0]
        set args [lreplace $args 0 0]
    }

    # Create a namespace to hold the variables for this command.
    namespace eval Commands::$procName {
        variable uri       {} ;# the XML namespace URI for this method 
        variable proxy     {} ;# URL for the location of a provider
        variable params    {} ;# list of name type pairs for the parameters
        variable reply     {} ;# the type of the reply (string, integer ...)
        variable transport {} ;# the transport procedure for this method
        variable name      {} ;# SOAP method name
        variable action    {} ;# Contents of the SOAPAction header
        variable http      {} ;# the http data variable (if used)
    }

    # call configure from the callers level so it can get the namespace.
    return [uplevel 1 "[namespace current]::configure $procName $args"]
}

# -------------------------------------------------------------------------

# Perform a SOAP method using the configured transport.

proc SOAP::invoke { procName args } {
    set valid [catch { set url [get2 Commands::$procName proxy] } msg]
    if { $valid != 0 } {
        error "invalid command: \"$procName\" not defined"
    }
    
    # Get the DOM object containing our request
    # We have to strip out the DOCTYPE element though. It would be better to
    # remove the DOM element, but that didn't work.
    set doc [eval "Commands::${procName}::xml $procName $args"]
    set prereq [dom::DOMImplementation serialize $doc]
    set req {}
    dom::DOMImplementation destroy $doc          ;# clean up
    regsub {<!DOCTYPE[^>]*>\n} $prereq {} req    ;# hack

    # Send the SOAP packet using the configured transport.
    set transport [ get Commands::$procName transport ]
    set reply [ $transport $procName $url $req ]

    # Parse the SOAP reply. ---- DO FAULT PROCESSING HERE ----
    package require SOAP::xpath
    set dom [dom::DOMImplementation parse $reply]
    set fault [catch { SOAP::xpath::xpath $dom "Envelope/Body/Fault" }]
    if { $fault == 0 } {
        error [concat \
                [SOAP::xpath::xpath {Envelope/Body/Fault/faultcode}] \
                [SOAP::xpath::xpath {Envelope/Body/Fault/faultstring}] ]
    } else {
        package require SOAP::Parse
        set not_dom [SOAP::Parse::parse $reply]
        #set not_dom [SOAP::xpath::xpath $dom "Envelope/Body//*"]
    }

    return $not_dom
}

# -------------------------------------------------------------------------

# HTTP transport expects a url and the SOAP data.
# If you need to use a proxy or have some other configuration then you must
# setup the http package independently eg:
#  ::http::config -proxyhost wwwproxy

proc SOAP::transport_http { procName url request } {
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
    lappend headers "SOAPAction" [get Commands::$procName action]

    # cleanup the last http request
    if { [get Commands::${procName} http] != {} } {
        catch { eval "::http::cleanup \$Commands::${procName}::http" }
    }

    # POST and get the reply.
    set reply [ ::http::geturl $url -headers $headers \
            -type text/xml -query $request ]

    # store the http structure for possible access later.
    set Commands::${procName}::http $reply

    if { [::http::ncode $reply ] == 500 } {
        package require SOAP::xpath
        set dr [dom::DOMImplementation parse [::http::data $reply]]
        set tr [concat \
                [SOAP::xpath::xpath $dr {Envelope/Body/Fault/faultcode}] \
                [SOAP::xpath::xpath $dr {Envelope/Body/Fault/faultstring}] ]
        dom::DOMImplementation destroy $dr
        error $tr
    }

    if { [::http::status $reply] != "ok" || [::http::ncode $reply ] != 200 } {
         error "SOAP transport error: \"[::http::code $reply]\""
    }

    set r [::http::data $reply]
    return $r
}

# -------------------------------------------------------------------------

# A dummy SOAP transport procedure to examine the SOAP requests generated.

proc SOAP::transport_print { procName url soap } {
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
                        error [concat "invalid option \"$opt\":" \
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
            error "SOAP transport \"$transport\" is undefined."
        }
    }
}

# Local variables:
#    indent-tabs-mode: nil
# End: