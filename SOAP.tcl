# SOAP.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide Tcl access to SOAP 1.1 methods.
#
# See http://tclsoap.sourceforge.net/ for usage details.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide SOAP 1.5

# -------------------------------------------------------------------------

package require http 2.0
package require SOAP::Parse

if { [catch {package require dom 2.0} domVer]} {
    if { [catch {package require dom 1.6} domVer]} {
        error "require dom package greater than 1.6"
    }
    package require SOAP::xpath
}

namespace eval SOAP {
    variable version 1.4
    variable domVersion $domVer
    variable rcs_version { $Id: SOAP.tcl,v 1.19 2001/06/21 00:18:47 patthoyts Exp $ }

    namespace export create cget dump configure proxyconfig
}

unset domVer

# -------------------------------------------------------------------------

# Description:
#   Provide a version independent selectNode implementation. We either use
#   the version from the dom package or use the SOAP::xpath version if there
#   is no dom one.
# Parameters:
#   node  - reference to a dom tree
#   path  - XPath selection
# Result:
#   Returns the selected node or a list of matching nodes or an empty list
#   if no match.
#
proc SOAP::selectNode {node path} {
    variable domVersion
    if {$domVersion < 2.0} {
        if {[catch {xpath::xpath -node $node $path} r]} {
            set r {}
        }
        return $r
    } else {
        return [dom::DOMImplementation selectNode $node $path]
    }
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

# Description:
#   Called from SOAP package methods, shift up to the callers level and
#   get the fully namespace qualified name for the given proc / var
# Parameters:
#   name - the name of a Tcl entity, or list of command and arguments
# Result:
#   Fully qualified namespace path for the named entity. If the name 
#   parameter is a list the the first element is namespace qualified
#   and the remainder of the list is unchanged.
#
proc SOAP::qualifyNamespace {name} {
    if {$name != {}} {
        set name [lreplace $name 0 0 \
                [uplevel 2 namespace origin [lindex $name 0]]]
    }
    return $name
}

# -------------------------------------------------------------------------

proc SOAP::methodVarName {methodName} {
    set name [uplevel 2 namespace origin $methodName]
    regsub -all {::+} $name {_} name
    return [namespace current]::$name
}

# -------------------------------------------------------------------------

# Retrieve configuration variables

proc SOAP::cget { args } {

    if { [llength $args] != 2 } {
        error "wrong # args: should be \"cget methodName optionName\""
    }

    set methodName [lindex $args 0]
    set optionName [lindex $args 1]
    set configVarName [methodVarName $methodName]

    if {[catch {set [subst $configVarName]([string trimleft $optionName "-"])} result]} {
        error "unknown option \"$option\""
    }
    return $result
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

# Description:
#   Configure or display a SOAP method options.
# Parameters:
#   procName - the SOAP method Tcl procedure name
#   args     - list of option name / option pairs
# Result:
#   Sets up a configuration array for the SOAP method.

proc SOAP::configure { procName args } {
    # The list of valid options
    set options { uri proxy params name transport action \
                      wrapProc replyProc parseProc postProc }

    if { $procName == "-transport" } {
        return [eval "transport_configure $args"]
    }

    # construct the name of the options array from the procName.
    set procVarName "[uplevel namespace current]::$procName"
    regsub -all {::+} $procVarName {_} procVarName
    set procVarName [namespace current]::$procVarName

    # Check that the named method has actually been defined
    if {! [array exists $procVarName]} {
        error "invalid command: \"$procName\" not defined"
    }

    # if no args - print out the current settings.
    if { [llength $args] == 0 } {
        set r {}
        foreach {opt value} [array get $procVarName] {
            lappend r -$opt $value
        }
        return $r
    }

    foreach {opt value} $args {
        switch -- $opt {
            -uri       { set [subst $procVarName](uri) $value }
            -proxy     { set [subst $procVarName](proxy) $value }
            -params    { set [subst $procVarName](params) $value }
            -transport { set [subst $procVarName](transport) $value }
            -name      { set [subst $procVarName](name) $value }
            -action    { set [subst $procVarName](action) $value }
            -wrapProc  { set [subst $procVarName](wrapProc) \
                    [qualifyNamespace $value] }
            -replyProc { set [subst $procVarName](replyProc) \
                    [qualifyNamespace $value] }
            -parseProc { set [subst $procVarName](parseProc) \
                    [qualifyNamespace $value] }
            -postProc  { set [subst $procVarName](postProc) \
                    [qualifyNamespace $value] }
            -command   { set [subst $procVarName](command) \
                    [qualifyNamespace $value] }
            default {
                error "unknown option \"$opt\": must be one of ${options}"
            }
        }
    }

    if { [set [subst $procVarName](name)] == {} } { 
        set [subst $procVarName](name) $procName
    }

    if { [set [subst $procVarName](transport)] == {} } {
        set [subst $procVarName](transport) \
                [namespace current]::Transport::http::xfer
    } 
    
    # Select the default parser unless one is specified
    if { [set [subst $procVarName](parseProc)] == {} } {
        set [subst $procVarName](parseProc) \
                [namespace current]::parse_soap_response
    } 

    # If no request wrapper is set, use the default SOAP wrap proc.
    if { [set [subst $procVarName](wrapProc)] == {} } {
        set [subst $procVarName](wrapProc) \
                [namespace current]::soap_request
    }

    uplevel 1 "proc $procName { args } {eval [namespace current]::invoke $procVarName \$args}"

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

    set ns "[uplevel namespace current]::$procName"
    regsub -all {::+} $ns {_} varName
    set varName [namespace current]::$varName
    array set $varName {}
    array set $varName {uri       {}} ;# the XML namespace URI for this method 
    array set $varName {proxy     {}} ;# URL for the location of a provider
    array set $varName {params    {}} ;# name/type pairs for the parameters
    array set $varName {transport {}} ;# transport procedure for this method
    array set $varName {name      {}} ;# SOAP method name
    array set $varName {action    {}} ;# Contents of the SOAPAction header
    array set $varName {http      {}} ;# the http data variable (if used)
    array set $varName {wrapProc  {}} ;# encode request into XML for sending
    array set $varName {replyProc {}} ;# post process the raw XML result
    array set $varName {parseProc {}} ;# parse raw XML and extract the values
    array set $varName {postProc  {}} ;# post process the parsed result
    array set $varName {command   {}} ;# asynchronous reply handler

    # call configure from the callers level so it can get the namespace.
    return [uplevel 1 "[namespace current]::configure $procName $args"]
}

# -------------------------------------------------------------------------

# Description:
#   Make a SOAP method call using the configured transport.
# Parameters:
#   procName  - the SOAP method configuration variable path
#   args      - the parameter list for the SOAP method call
# Returns:
#   Returns the parsed and processed result of the method call
#
proc SOAP::invoke { procVarName args } {
    set procName [lindex [split $procVarName {_}] end]
    if {![array exists $procVarName]} {
        error "invalid command: \"$procName\" not defined"
    }

    # Get the URL
    set url [set [subst $procVarName](proxy)]

    # Get the XML data containing our request
    set req [eval "[set [subst $procVarName](wrapProc)] $procVarName $args"]

    # Send the SOAP packet (req) using the configured transport.
    set transport [set [subst $procVarName](transport)]
    set reply [$transport $procVarName $url $req]

    # Check for an async command handler. If async then return now,
    # otherwise call the invoke second stage immediately.
    if { [set [subst $procVarName](command)] != {} } {
        return $reply
    }
    return [invoke2 $procVarName $reply]
}

# -------------------------------------------------------------------------

# Description:
#   The second stage of the method invocation deals with unwrapping the
#   reply packet that has been received from the remote service.
# Parameters:
#   procName  - the SOAP method configuration variable path
#   reply     - the raw data returned from the remote service
# Notes:
#   This has been separated from `invoke' to support asynchronous
#   transports. It calls the various unwrapping hooks in turn.
#
proc SOAP::invoke2 {procVarName reply} {
    set ::lastReply $reply

    set procName [lindex [split $procVarName {_}] end]

    # Post-process the raw XML using -replyProc
    set replyProc [set [subst $procVarName](replyProc)]
    if { $replyProc != {} } {
        set reply [$replyProc $procName $reply]
    }

    # Call the relevant parser to extract the returned values
    set parseProc [set [subst $procVarName](parseProc)]
    if { $parseProc == {} } {
        set parseProc parse_soap_response
    }
    set r [$parseProc $procName $reply]

    # Post process the parsed reply using -postProc
    set postProc [set [subst $procVarName](postProc)]
    if { $postProc != {} } {
        set r [$postProc $procName $r]
    }

    return $r
}

# -------------------------------------------------------------------------

# Description:
#   Handle a proxy server.
# Notes:
#   Needs expansion to use a list of non-proxied sites or a list of
#   {regexp proxy} or something.
#   The proxy variable in this namespace is set up by 
#   configure -transport http.
#
namespace eval SOAP::Transport::http {
    variable options

    proc filter {host} {
        variable options
        if { [string match "localhost*" $host] \
                || [string match "127.*" $host] } {
            return {}
        }
        return [lrange [split $options(proxy) {:}] 0 1]
    }

    # Provide missing code for http < 2.3
    if {[info proc ::http::ncode] == {}} {
        namespace eval ::http {
            proc ncode {token} {
                return [lindex [split [code $token]] 1]
            }
        }
    }
}

# -------------------------------------------------------------------------

# Description:
#   Perform a remote procedure call using HTTP as the transport protocol.
#   This uses the Tcl http package to do the work. If the SOAP method has
#   the -command option set to something then the call is made 
#   asynchronously and the result data passed to the users callback
#   procedure.
#   If you have an HTTP proxy to deal with then you should set up the 
#   SOAP::Transport::http::filter procedure and proxy variable to suit.
#   This can be done using SOAP::proxyconfig.
# Parameters:
#   procVarName - 
#   url         -
#   request     -
# Result:
#   The request data is POSTed to the SOAP provider via HTTP using any
#   configured proxy host. If the HTTP returns an error code then an error
#   is raised otherwise the reply data is returned. If the method has
#   been configured to be asynchronous then the async handler is called
#   once the http request completes.
#
proc SOAP::Transport::http::xfer { procVarName url request } {
    variable options

    # Get the SOAP package version
    set version [set [namespace parent [namespace parent]]::version]

    # setup the HTTP POST request
    ::http::config -useragent "TclSOAP/$version ($::tcl_platform(os))"

    # If a proxy was configured, use it.
    if { [info exists options(proxy)] && $options(proxy) != {} } {
        ::http::config -proxyfilter [namespace origin filter]
    }

    # Check for an HTTP progress callback.
    set local_progress {}
    if { [info exists options(progress)] && $options(progress) != {} } {
        set local_progress "-progress [list $options(progress)]"
    }
    
    # There may be http headers configured. eg: for proxy servers
    # eg: SOAP::configure -transport http -headers 
    #    [list "Proxy-Authorization" [basic_authorization]]
    set local_headers {}
    if {[info exists options(headers)]} {
        set local_headers $headers
    }

    # Add mandatory SOAPAction header (SOAP 1.1). This may be empty otherwise
    # must be in quotes.
    set action [set [subst $procVarName](action)]
    if { $action != {} } { 
        set action [string trim $action "\""]
        set action "\"$action\""
    }
    lappend local_headers "SOAPAction" $action

    # cleanup the last http request
    if { [set [subst $procVarName](http)] != {} } {
        catch { eval "::http::cleanup [set [subst $procVarName](http)]" }
    }

    # Check for an asynchronous handler and perform the transfer.
    # If async - return immediately.
    set command {}
    if {[set [subst $procVarName](command)] != {}} {
        set command "-command {[namespace current]::asynchronous $procVarName}"
    }

    set token [eval ::http::geturl [list $url] \
            -headers [list $local_headers] \
            -type text/xml -query [list $request] \
            $local_progress $command]
    set [subst $procVarName](http) $token
    if { $command != {}} { return {} }
    

    # store the http structure reference for possible access later.
    set [subst $procVarName](http) $token

    # Some other sort of error ...
    if {[::http::status $token] != "ok"} {
         error "SOAP transport error: \"[::http::code $token]\""
    }

    return [::http::data $token]
}

# -------------------------------------------------------------------------

# Description:
#    Asynchronous http handler command.
proc SOAP::Transport::http::asynchronous {procVarName token} {
    if {[catch {asynchronous2 $procVarName $token} msg]} {
        bgerror $msg
    }
    return $msg
}

proc SOAP::Transport::http::asynchronous2 {procVarName token} {
    set procName [lindex [split $procVarName {_}] end]

    # Some other sort of error ...
    if {[::http::status $token] != "ok"} {
         error "SOAP transport error: \"[::http::code $token]\""
    }

    set reply [::http::data $token]

    # Call the second part of invoke to unwrap the packet data.
    set reply [SOAP::invoke2 $procVarName $reply]

    # Call the users handler.
    set command [set [subst $procVarName](command)]
    return [eval $command [list $reply]]
}

# -------------------------------------------------------------------------

# Description:
#   A dummy SOAP transport procedure to examine the SOAP requests generated.
# Parameters:
#   procVarName  - SOAP method name configuration variable
#   url          - URL of the remote server method implementation
#   soap         - the XML payload for this SOAP method call
#
proc SOAP::transport_print { procVarName url soap } {
    puts "$soap"
    return {}
}

# -------------------------------------------------------------------------

# Description:
#   Helper procedure called from configure used to setup the SOAP transport
#   options. Calling `invoke' for a method will call the configured 
#   transport procedure.
# Parameters:
#   transport - the name of the transport mechanism (smtp, http, etc)
#   args      - list of options for the named transport mechanism
#
proc SOAP::transport_configure { transport args } {
    switch -- $transport {
        http {
            # If no args then print out the current settings
            if { $args == {} } {
                set r {}
                foreach {opt value} [array get Transport::http::options] {
                    lappend r "-$opt" $value
                }
                return $r
            }
            
            foreach {opt value} $args {
                switch -- $opt {
                    -proxy   {
                        set Transport::http::options(proxy) [list $value]
                    }
                    -headers {
                        set Transport::http::options(headers) [list $value]
                    }
                    -progress {
                        set Transport::http::options(progress) [list $value]
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
            error "SOAP transport \"$transport\" is undefined: \
                    must be one of \"http\" or \"print\"."
        }
    }
}

# -------------------------------------------------------------------------

# Description:
#   Setup SOAP HTTP transport for an authenticating proxy HTTP server.
#   At present the SOAP package only supports Basic authentication and this
#   dialog is used to configure the proxy information.
# Parameters:
#   none

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

    toplevel .tx
    wm title .tx "Proxy Configuration"
    set m [message .tx.m1 -relief groove -justify left -width 6c -aspect 200 \
            -text "Enter details of your proxy server (if any) and your username and password if it is needed by the proxy."]
    set f1 [frame .tx.f1]
    set f2 [frame .tx.f2]
    button $f2.b -text "OK" -command {destroy .tx}
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
    tkwait window .tx
    SOAP::configure -transport http -proxy $SOAP::conf_proxy
    if { [info exists SOAP::conf_userid] } {
        SOAP::configure -transport http \
            -headers [list "Proxy-Authorization" \
            "Basic [lindex [$local64 ${SOAP::conf_userid}:${SOAP::conf_passwd}] 0]" ]
    }
    unset SOAP::conf_passwd
}

# -------------------------------------------------------------------------

# Description:
#   Procedure to generate the XML data for a configured SOAP procedure.
# Parameters:
#   procVarName - the path of the SOAP method configuration variable
#   args        - the arguments for this SOAP method
# Result:
#   XML data containing the SOAP method call.
#
proc SOAP::soap_request {procVarName args} {

    set procName [lindex [split $procVarName {_}] end]
    set params [set [subst $procVarName](params)]
    set name [set [subst $procVarName](name)]
    set uri [set [subst $procVarName](uri)]
    
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

    # We have to strip out the DOCTYPE element though. It would be better to
    # remove the DOM element, but that didn't work.
    set prereq [dom::DOMImplementation serialize $doc]
    set req {}
    dom::DOMImplementation destroy $doc          ;# clean up
    regsub "<!DOCTYPE\[^>\]*>\n" $prereq {} req  ;# hack

    return $req                                  ;# return the XML data
}

# -------------------------------------------------------------------------

# Description:
#   Procedure to generate the XML data for a configured XML-RPC procedure.
# Parameters:
#   procVarName - the name of the XML-RPC method variable
#   args        - the arguments for this RPC method
# Result:
#   XML data containing the XML-RPC method call.
#
proc SOAP::xmlrpc_request {procVarName args} {

    set procName [lindex [split $procVarName {_}] end]
    set params [set [subst $procVarName](params)]
    set name   [set [subst $procVarName](name)]
    
    if { [llength $args] != [expr [llength $params] / 2]} {
        set msg "wrong # args: should be \"$procName"
        foreach { id type } $params {
            append msg " " $id
        }
        append msg "\""
        error $msg
    }
    
    set doc [dom::DOMImplementation create]
    set d_root [dom::document createElement $doc "methodCall"]
    set d_meth [dom::document createElement $d_root "methodName"]
    dom::document createTextNode $d_meth $name
    
    if { [llength $params] != 0 } {
        set d_params [dom::document createElement $d_root "params"]
    }
    
    set param 0
    foreach {key type} $params {
        set d_param [dom::document createElement $d_params "param"]
        set d_pname [dom::document createElement $d_param "value"]
        
        if { [string match {struct} $type] } {

            # XMLRPC struct type
            set d_struct [dom::document createElement $d_pname "struct"]
            foreach {sid sval} [lindex $args $param] {
                set d_mmbr [dom::document createElement $d_struct "member"]
                set d_mnam [dom::document createElement $d_mmbr "name"]
                dom::document createTextNode $d_mnam $sid
                set d_mval [dom::document createElement $d_mmbr "value"]
                set d_mtyp [dom::document createElement $d_mval \
                        [[namespace parent]::XMLRPC::TypedVariable::get_type $sval]]
                dom::document createTextNode $d_mtyp \
                        [[namespace parent]::XMLRPC::TypedVariable::get_value $sval]
            }

        } elseif { [regexp {^array\((.*)\)} $type match subtype] } {
            # XMLRPC Array type
            set d_array [dom::document createElement $d_pname "array"]
            set d_data  [dom::document createElement $d_array "data"]
            foreach elt [lindex $args $param] {
                set d_value [dom::document createElement $d_data "value"]
                set d_type [dom::document createElement $d_value $subtype]
                dom::document createTextNode $d_type \
                        [[namespace parent]::XMLRPC::TypedVariable::get_value $elt]
            }
        } else {
            set d_ptype [dom::document createElement $d_pname $type]
            dom::document createTextNode $d_ptype \
                    [[namespace parent]::XMLRPC::TypedVariable::get_value [lindex $args $param]]
        }
        incr param
    }

    # We have to strip out the DOCTYPE element though. It would be better to
    # remove the DOM element, but that didn't work.
    set prereq [dom::DOMImplementation serialize $doc]
    set req {}
    dom::DOMImplementation destroy $doc          ;# clean up
    regsub "<!DOCTYPE\[^>\]*>\n" $prereq {} req  ;# hack

    return $req                                  ;# return the XML data
}

# -------------------------------------------------------------------------

# Description:
#   Parse a SOAP response payload. Check for Fault response otherwise 
#   extract the value data.
# Parameters:
#   procVarName  - the name of the SOAP method configuration variable
#   xml          - the XML payload of the response
# Result:
#   The returned value data.
# Notes:
#   Needs work to cope with struct or array types.
#
proc SOAP::parse_soap_response { procVarName xml } {
    # Sometimes Fault packets come back with HTTP code 200
    set doc [dom::DOMImplementation parse $xml]

    set faultNode [selectNode $doc "/Envelope/Body/Fault"]
    if {$faultNode != {}} {
        set fault [SOAP::Parse::parse $xml]
        dom::DOMImplementation destroy $doc
        error [lrange $fault 0 1] [lrange $fault 2 end]
    }
    
    set result {}
    set nodes [subElements [selectNode $doc "/Envelope/Body"]]
    foreach node $nodes {
        set r [getSubElementValues $node]
        if {$result == {}} { set result $r } else { lappend result $r }
    }

    dom::DOMImplementation destroy $doc
    return $result
}

# -------------------------------------------------------------------------

# Description:
#   If there are child elements then recursively call this procedure on each
#   child element. If this is a leaf element, then get the element value data.
# Parameters:
#   domElement - a reference to a dom element node
# Result:
#   Returns a value or a list of values.
#
proc SOAP::getSubElementValues {domElement} {
    set result {}
    set nodes [subElements $domElement]
    if {$nodes == {}} {
        set result [getElementValue $domElement]
    } else {
        foreach node $nodes {
            set r [getSubElementValues $node]
            if {$result == {}} { set result $r } else { lappend result $r }
        }
    }
    return $result
}

# -------------------------------------------------------------------------

# Description:
#   Parse an XML-RPC response payload. Check for fault response otherwise 
#   extract the value data.
# Parameters:
#   procVarName  - the name of the XML-RPC method configuration variable
#   xml          - the XML payload of the response
# Result:
#   The extracted value(s). Array types are converted into lists and struct
#   types are turned into lists of name/value pairs suitable for array set
# Notes:
#   The XML-RPC fault response doesn't allow us to add in extra values
#   to the fault struct. So where to put the servers errorInfo?
#
proc SOAP::parse_xmlrpc_response { procVarName xml } {
    set result {}
    set doc [dom::DOMImplementation parse $xml]

    set faultNode [selectNode $doc "/methodResponse/fault"]
    if {$faultNode != {}} {
        array set err [SOAP::Parse::parse $xml]
        dom::DOMImplementation destroy $doc
        error $err(faultString) {} $err(faultCode)
    }
    
    # Recurse over each params/param/value
    set n_params 0
    foreach valueNode [selectNode $doc \
            "/methodResponse/params/param/value"] {
        lappend result [xmlrpc_value_from_node $valueNode]
        incr n_params
    }

    dom::DOMImplementation destroy $doc

    # If (as is usual) there is only one param, simplify things for the user
    # ie: sort {one two three} should return a 3 element list, not a single
    # element list whose first element has 3 elements!
    if {$n_params == 1} {set result [lindex $result 0]}
    return $result
}

# -------------------------------------------------------------------------

### NB: the code below this comment needs to be moved into XMLRPC namespace

# Description:
#   Retrieve the value under the given <value> node.
# Parameters:
#   valueNode - reference to a <value> element in the response dom tree
# Result:
#   Either a single value or a list of values. Arrays expand into a list
#   of values, structs to a list of name/value pairs.
# Notes:
#   Called recursively when processing arrays and structs.
#
proc SOAP::xmlrpc_value_from_node {valueNode} {
    set value {}
    set elts [subElements $valueNode]
    if {[llength $elts] != 1} {
        return [getElementValue $valueNode]
    }
    set typeElement [lindex $elts 0]
    set type [dom::node cget $typeElement -nodeName]

    if {$type == "array"} {
        set dataElement [lindex [subElements $typeElement] 0]
        foreach valueElement [subElements $dataElement] {
            lappend value [xmlrpc_value_from_node $valueElement]
        }
    } elseif {$type == "struct"} {
        # struct type has 1+ members which have a name and a value elt.
        foreach memberElement [subElements $typeElement] {
            set params [subElements $memberElement]
            foreach param $params {
                set nodeName [dom::node cget $param -nodeName]
                if { $nodeName == "name"} {
                    set pname [getElementValue $param]
                } elseif { $nodeName == "value" } {
                    set pvalue [xmlrpc_value_from_node $param]
                }
            }
            lappend value $pname $pvalue
        }
    } else {
        set value [getElementValue $typeElement]
    }
    return $value
}

# -------------------------------------------------------------------------

# Description:
#   Return a list of all the immediate children of domNode that are element
#   nodes.
# Parameters:
#   domNode  - a reference to a node in a dom tree
#
proc SOAP::subElements {domNode} {
    set elements {}
    foreach node [dom::node children $domNode] {
        if {[dom::node cget $node -nodeType] == "element"} {
            lappend elements $node
        }
    }
    return $elements
}

# -------------------------------------------------------------------------

# Description:
#   Merge together all the child node values under a given dom element
# Params:
#   domElement  - a reference to an element node in a dom tree
# Result:
#   A string containing the elements value
#
proc SOAP::getElementValue {domElement} {
    set r {}
    set dataNodes [dom::node children $domElement]
    foreach dataNode $dataNodes {
        append r [dom::node cget $dataNode -nodeValue]
    }
    return $r
}

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
