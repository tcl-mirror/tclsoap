# SOAP.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide Tcl access to SOAP 1.1 methods.
# See http://www.zsplat.freeserve.co.uk/soap/doc/TclSOAP.html
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

package provide SOAP 1.3

# -------------------------------------------------------------------------

package require http 2.3
package require SOAP::Parse
package require SOAP::xpath

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

namespace eval SOAP {
    variable version 1.3
    variable rcs_version { $Id: SOAP.tcl,v 1.12 2001/04/19 00:05:59 pat Exp pat $ }

    namespace export create cget dump configure proxyconfig
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

# Dump the HTTP data from the last request performed.
# Options to dump the HTTP meta data the reply data or the XML of the
# SOAP request that was posted to the server
#
proc SOAP::dump {args} {
    if {[llength $args] == 1} {
        set type -reply
        set methodName [lindex $args 0]
    } elseif { [llength $args] == 2 } {
        set type [lindex $args 0]
        set methodName [lindex $args 1]
    } else {
        error "wrong # args: should be \"dump ?option? methodName\""
    }

    # Check that methodName exists and has a http variable.
    if { [catch {cget $methodName http} token] } {
        error "invalid method name: \"$methodName\" is not a SOAP command"
    }
    if { $token == {} } {
        error "no information HTTP information available for SOAP method \"$methodName\""
    }

    set result {}
    switch -glob -- $type {
        -meta   {set result [lindex [array get $token meta] 1]}
        -qu*    -
        -req*   {set result [lindex [array get $token -query] 1]}
        -rep*   {set result [::http::data $token]}
        default {
            error "unrecognised option: must be one of \
                    \"-meta\", \"-request\" or \"-reply\""
        }
    }

    return $result
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
    set reply [$transport $procName $url $req]

    # Sometimes Fault packets come back with HTTP code 200
    set doc [dom::DOMImplementation parse $reply]
    if { ! [catch {SOAP::xpath::xpath $doc "/Envelope/Body/Fault"} ] } {
        set fault [SOAP::Parse::parse $reply]
        error [lrange $fault 0 1] [lrange $fault 2 end]
    }

    # Extract the data from the reply XML
    set r [SOAP::Parse::parse $reply]
    #set r [SOAP::xpath::xpath $dom "Envelope/Body//*"]

    return $r
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
        ::http::config -proxyfilter \
                [namespace current]::Transport::http::filter
    }
    
    # There may be http headers configured. eg: for proxy servers
    # eg: SOAP::configure -transport http -headers 
    #    [list "Proxy-Authorization" [basic_authorization]]
    set headers [get Transport::http headers]

    # Add mandatory SOAPAction header (SOAP 1.1). This may be empty otherwise
    # must be in quotes.
    set action [get Commands::$procName action]
    if { $action != {} } { 
        set action [string trim $action "\""]
        set action "\"$action\""
    }
    lappend headers "SOAPAction" $action

    # cleanup the last http request
    if { [get Commands::${procName} http] != {} } {
        catch { eval "::http::cleanup \$Commands::${procName}::http" }
    }

    # POST and get the reply.
    set reply [ ::http::geturl $url -headers $headers \
            -type text/xml -query $request ]

    # store the http structure for possible access later.
    set Commands::${procName}::http $reply

    # If it's a fault then add any <detail> elements to the error stack.
    if { [::http::ncode $reply ] == 500 } {
        set fault [SOAP::Parse::parse [::http::data $reply]]
        error [lrange $fault 0 1] [lrange $fault 2 end]
    }

    # Some other sort of error ...
    if { [::http::status $reply] != "ok" || [::http::ncode $reply ] != 200 } {
         error "SOAP transport error: \"[::http::code $reply]\""
    }

    set r [::http::data $reply]
    return $r
}

# -------------------------------------------------------------------------

# Handle a proxy server.
# Needs expansion to use a list of non-proxied sites or a list of
# {regexp proxy} or something.
# The proxy variable in this namespace is set up by 
# configure -transport http.
namespace eval SOAP::Transport::http {
    proc filter {host} {
        variable proxy
        if { [string match "localhost*" $host] \
                || [string match "127.*" $host] } {
            return {}
        }
        return [lrange [split $proxy {:}] 0 1]
    }
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
            # If no args then print out the current settings
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
                                "variable proxy [list $value]"
                    }
                    -headers {
                        namespace eval Transport::$transport \
                                "variable headers [list $value]"
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

# -------------------------------------------------------------------------

# Setup SOAP HTTP transport for an authenticating proxy HTTP server.
# This is used for me to test at work.

proc SOAP::proxyconfig {} {
    package require Tk
    if { [catch {package require base64}] } {
        if { [catch {package require Trf}] } {
            error "proxyconfig requires either tcllib or Trf packages."
        } else {
            set local64 "base64 -mode enc"
        }
    } else {
        set local64 "base64::encode"
    }

    toplevel .t
    wm title .t "Proxy Configuration"
    set m [message .t.m1 -relief groove -justify left -width 6c -aspect 200 \
            -text "Enter details of your proxy server (if any) and your username and password if it is needed by the proxy."]
    set f1 [frame .t.f1]
    set f2 [frame .t.f2]
    button $f2.b -text "OK" -command {destroy .t}
    pack $f2.b -side right
    label $f1.l1 -text "Proxy (host:port)"
    label $f1.l2 -text "Username"
    label $f1.l3 -text "Password"
    entry $f1.e1 -textvariable SOAP::conf_proxy
    entry $f1.e2 -textvariable SOAP::conf_userid
    entry $f1.e3 -textvariable SOAP::conf_passwd -show {*}
    grid $f1.l1 -column 0 -row 0 -sticky e
    grid $f1.l2 -column 0 -row 1 -sticky e
    grid $f1.l3 -column 0 -row 2 -sticky e
    grid $f1.e1 -column 1 -row 0 -sticky news
    grid $f1.e2 -column 1 -row 1 -sticky news
    grid $f1.e3 -column 1 -row 2 -sticky news
    grid columnconfigure $f1 1 -weight 1
    pack $f2 -side bottom -fill x
    pack $m  -side top -fill x -expand 1
    pack $f1 -side top -anchor n -fill both -expand 1
    tkwait window .t
    SOAP::configure -transport http -proxy $SOAP::conf_proxy
    if { [info exists SOAP::conf_userid] } {
        SOAP::configure -transport http \
            -headers [list "Proxy-Authorization" \
            "Basic [lindex [$local64 ${SOAP::conf_userid}:${SOAP::conf_passwd}] 0]" ]
    }
    unset SOAP::conf_passwd
}

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End: