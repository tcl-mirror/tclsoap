# -------------------------------------------------------------------------
# Examples of SOAP methods for use with SOAP::Domain under the tclhttpd
# web sever.
# -------------------------------------------------------------------------
#

# Load the SOAP URL domain handler into the web server and register it under
# the /soap URL. All methods need to be defined in the SOAP::Domain
# namespace and begin with /. Thus my /base64 procedure will be called 
# via the URL http://localhost:8015/soap/base64
#
package require base64
package require SOAP::Domain
SOAP::Domain::register -prefix /soap -namespace zsplat::Test

namespace eval zsplat::Test {}

# -------------------------------------------------------------------------
# base64 - convert the input string parameter to a base64 encoded string
#
proc zsplat::Test::/base64 {text} {
    return [base64::encode $text]
}

# -------------------------------------------------------------------------
# time - return the servers idea of the time
#
proc zsplat::Test::/time {} {
    return [clock format [clock seconds]]
}

# -------------------------------------------------------------------------
# rcsid - return the RCS version string for this package
#
proc zsplat::Test::/rcsid {} {
    return ${::SOAP::Domain::rcs_id}
}

# -------------------------------------------------------------------------
# square - test validation of numerical methods.
#
proc zsplat::Test::/square {num} {
    if { [catch {expr $num + 0}] } {
        error "parameter num must be a number"
    }
    return [expr $num * $num]
}

# -------------------------------------------------------------------------
# sort - sort a list
#
proc zsplat::Test::/sort {args} {
    eval set n $args
    return [lsort $n]
}

# -------------------------------------------------------------------------
# Test out a COM calling extension.
#
proc zsplat::Test::/WiRECameras/get_Count {} {
    package require Renicam
    return [renicam count]
}

# -------------------------------------------------------------------------

proc zsplat::Test::/WiRECameras/Add {} {
    package require Renicam
    return [renicam add]
}

# -------------------------------------------------------------------------
