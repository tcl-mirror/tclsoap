# -------------------------------------------------------------------------
# Examples of XML-RPC methods for use with XMLRPC::Domain under the tclhttpd
# web sever.
# -------------------------------------------------------------------------
#

# Load the XMLRPC URL domain handler into the web server and register it under
# the /rpc URL. All methods need to be defined in the zsplat::RPC
# namespace and begin with /. Thus my /base64 procedure will be called 
# via the URL http://localhost:8015/soap/base64
#
package require base64
package require XMLRPC::Domain
package require XMLRPC::TypedVariable

catch {XMLRPC::Domain::register -prefix /rpc -namespace zsplat::RPC} msg
if { $msg != "URL prefix \"/rpc\" already registered"} {
    error $msg
}

namespace eval zsplat::RPC {}

# -------------------------------------------------------------------------
# base64 - convert the input string parameter to a base64 encoded string
#
proc zsplat::RPC::/base64 {text} {
    set result [base64::encode $text]
    set result [XMLRPC::TypedVariable::create base64 $result]
    return $result
}

# -------------------------------------------------------------------------
# time - return the servers idea of the time in iso8601 format
#
proc zsplat::RPC::/time {} {
    set result [clock format [clock seconds] -format {%Y%m%dT%H:%M:%S}]
    set result [XMLRPC::TypedVariable::create dateTime.iso8601 $result]
    return $result
}

# -------------------------------------------------------------------------
# rcsid - return the RCS version string for this package
#
proc zsplat::RPC::/rcsid {} {
    return "${::XMLRPC::Domain::rcs_id}"
}

# -------------------------------------------------------------------------
# square - test validation of numerical methods.
#
proc zsplat::RPC::/square {num} {
    if { [catch {expr $num + 0}] } {
        error "parameter num must be a number"
    }
    return [expr $num * $num]
}

# -------------------------------------------------------------------------
# sort - sort a list
#
proc zsplat::RPC::/sort {args} {
    eval set n $args
    set result [lsort $n]
    set result [XMLRPC::TypedVariable::create array $result]
    return $result
}

# -------------------------------------------------------------------------
# struct - generate a XML-RPC struct type
#
proc zsplat::RPC::/platform {} {
    set result [XMLRPC::TypedVariable::create struct \
		    [array get ::tcl_platform]]
    return $result
}
# -------------------------------------------------------------------------
# Test out a COM calling extension.
#
proc zsplat::RPC::/WiRECameras/get_Count {} {
    package require Renicam
    return [renicam count]
}

# -------------------------------------------------------------------------

proc zsplat::RPC::/WiRECameras/Add {} {
    package require Renicam
    return [renicam add]
}

# -------------------------------------------------------------------------
