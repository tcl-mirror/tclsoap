# http.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# The SOAP HTTP Transport.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package require http;                   # tcl

namespace eval SOAP::Transport::http {
    variable version 1.0
    variable rcsid {$Id$}
    variable options

    package provide SOAP::http $version

    SOAP::register http [namespace current]

    if {![info exists options]} {
        array set options {
            headers  {}
            proxy    {}
            progress {}
        }
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
#  Configure any http transport specific settings.
#
proc SOAP::Transport::http::configure {args} {
    variable options

    if {[llength $args] == 0} {
        set r {}
        foreach {opt value} [array get options] {
            lappend r "-$opt" $value
        }
        return $r
    }

    foreach {opt value} $args {
        switch -- $opt {
            -proxy   {
                set options(proxy) $value
            }
            -headers {
                set options(headers) $value
            }
            -progress {
                set options(progress) $value
            }
            default {
                error "invalid option \"$opt\":\
                      must be \"-proxy host:port\" or \"-headers list\""
            }
        }
    }
    return {}
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
#   procVarName - the name of the SOAP config array for this method.
#   url         - the SOAP endpoint URL
#   request     - the XML data making up the SOAP request
# Result:
#   The request data is POSTed to the SOAP provider via HTTP using any
#   configured proxy host. If the HTTP returns an error code then an error
#   is raised otherwise the reply data is returned. If the method has
#   been configured to be asynchronous then the async handler is called
#   once the http request completes.
#
proc SOAP::Transport::http::xfer { procVarName url request } {
    variable options
    upvar $procVarName procvar
    
    # Get the SOAP package version
    # FRINK: nocheck
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
        set local_headers $options(headers)
    }
    
    # Add mandatory SOAPAction header (SOAP 1.1). This may be empty otherwise
    # must be in quotes.
    set action $procvar(action)
    if { $action != {} } { 
        set action [string trim $action "\""]
        set action "\"$action\""
        lappend local_headers "SOAPAction" $action
    }
    
    # cleanup the last http request
    if {[info exists procvar(http)] && $procvar(http) != {}} {
        catch {::http::cleanup $procvar(http)}
    }
    
    # Check for an asynchronous handler and perform the transfer.
    # If async - return immediately.
    set command {}
    if {$procvar(command) != {}} {
        set command "-command {[namespace current]::asynchronous $procVarName}"
    }
    
    set token [eval ::http::geturl_followRedirects [list $url] \
                   -headers [list $local_headers] \
                   -type text/xml -query [list $request] \
                   $local_progress $command]
    
    # store the http structure reference for possible access later.
    set procvar(http) $token
    
    if { $command != {}} {
        return {} 
    }

    log::log debug "[::http::status $token] - [::http::code $token]"

    # Check for Proxy Authentication requests and handle it.
    if {[::http::ncode $token] == 407} {
        SOAP::proxyconfig
        return [xfer $procVarName $url $request]
    }

    # Some other sort of error ...
    if {[::http::status $token] != "ok"} {
         error "SOAP transport error: \"[::http::code $token]\""
    }

    return [::http::data $token]
}

# this proc contributed by [Donal Fellows]
proc ::http::geturl_followRedirects {url args} {
    set limit 10
    while {$limit > 0} {
        set token [eval [list ::http::geturl $url] $args]
        switch -glob -- [ncode $token] {
            30[1237] {
                incr limit -1
                ### redirect - see below ### 
            }
            default  { return $token }
        }
        upvar \#0 $token state
        array set meta [set ${token}(meta)]
        if {![info exist meta(Location)]} {
            return $token
        }
        set url $meta(Location)
        unset meta
    }
    error "maximum relocation depth reached: site loop?"
}


# -------------------------------------------------------------------------

# Description:
#    Asynchronous http handler command.
proc SOAP::Transport::http::asynchronous {procVarName token} {
    upvar $procVarName procvar

    if {[catch {asynchronous2 $procVarName $token} msg]} {
        if {$procvar(errorCommand) != {}} {
            set errorCommand $procvar(errorCommand)
            if {[catch {eval $errorCommand [list $msg]} result]} {
                bgerror $result
            }
        } else {
            bgerror $msg
        }
    }
    return $msg
}

proc SOAP::Transport::http::asynchronous2 {procVarName token} {
    upvar $procVarName procvar
    set procName [lindex [split $procVarName {_}] end]

    # Some other sort of error ...
    if {[::http::status $token] != "ok"} {
         error "SOAP transport error: \"[::http::code $token]\""
    }

    set reply [::http::data $token]

    # Call the second part of invoke to unwrap the packet data.
    set reply [SOAP::invoke2 $procVarName $reply]

    # Call the users handler.
    set command $procvar(command)
    return [eval $command [list $reply]]
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
proc SOAP::Transport::http::filter {host} {
    variable options
    if { [string match "localhost*" $host] \
             || [string match "127.*" $host] } {
        return {}
    }
    return [lrange [split $options(proxy) {:}] 0 1]
}

# -------------------------------------------------------------------------

# Description:
#  Called to release any retained resources from a SOAP method. For the
#  http transport this is just the http token.
# Parameters:
#  methodVarName - the name of the SOAP method configuration array
#
proc SOAP::Transport::http::cleanup {methodVarName} {
    upvar $methodVarName procvar
    if {[info exists procvar(http)] && $procvar(http) != {}} {
        catch {::http::cleanup $procvar(http)}
    }
}

# -------------------------------------------------------------------------

proc SOAP::Transport::http::dump {methodName type} {
    SOAP::cget $methodName proxy
    if {[catch {SOAP::cget $methodName http} token]} {
        set token {}
    }

    if { $token == {} } {
        error "cannot dump: no information is available for \"$methodName\""
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