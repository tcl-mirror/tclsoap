# soap-methods-server.tcl
#                   - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provides examples of SOAP methods for use with SOAP::Domain under the
# tclhttpd web sever.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id: soap-methods-server.tcl,v 1.2 2001/07/16 23:39:51 patthoyts Exp $

# Load the SOAP URL domain handler into the web server and register it under
# the /soap URL. All methods need to be defined in the SOAP::Domain
# namespace and begin with /. Thus my /base64 procedure will be called 
# via the URL http://localhost:8015/soap/base64
#
package require SOAP::Domain
package require rpcvar
namespace import -force rpcvar::*

SOAP::Domain::register -prefix /soap -namespace tclsoap::Test

namespace eval tclsoap::Test {}

# -------------------------------------------------------------------------
# base64 - convert the input string parameter to a base64 encoded string
#
proc tclsoap::Test::/base64 {text} {
    package require base64
    return [rpcvar base64 [base64::encode $text]]
}

# -------------------------------------------------------------------------
# time - return the servers idea of the time
#
proc tclsoap::Test::/time {} {
    return [clock format [clock seconds]]
}

# -------------------------------------------------------------------------
# rcsid - return the RCS version string for this package
#
proc tclsoap::Test::/rcsid {} {
    return ${::SOAP::Domain::rcs_id}
}

# -------------------------------------------------------------------------
# square - test validation of numerical methods.
#
proc tclsoap::Test::/square {num} {
    if { [catch {expr $num + 0}] } {
        error "parameter num must be a number"
    }
    return [expr $num * $num]
}

# -------------------------------------------------------------------------
# sum - test two parameter method
#
proc tclsoap::Test::/sum {lhs rhs} {
    return [expr $lhs + $rhs]
}

# -------------------------------------------------------------------------
# sort - sort a list
#
proc tclsoap::Test::/sort {myArray} {
    return [rpcvar "array" [lsort $myArray]]
}

# -------------------------------------------------------------------------
# platform - return a structure.
#
proc tclsoap::Test::/platform {} {
    return [rpcvar struct ::tcl_platform]
}

# -------------------------------------------------------------------------
# xml - return some XML data. Just to show it's not a problem.
#
proc tclsoap::Test::/xml {} {
    set xml {<?xml version="1.0" ?>
<memos>
   <memo>
      <subject>test memo one</subject>
      <body>The body of the memo.</body>
   </memo>
   <memo>
      <subject>test memo two</subject>
      <body>Memo body with specials: &quot; &amp; &apos; and &lt;&gt;</body>
   </memo>
</memos>
}
    return $xml
}

# -------------------------------------------------------------------------
# Test out a COM calling extension.
#
proc tclsoap::Test::/WiRECameras/get_Count {} {
    package require Renicam
    return [renicam count]
}

# -------------------------------------------------------------------------

proc tclsoap::Test::/WiRECameras/Add {} {
    package require Renicam
    return [renicam add]
}

# -------------------------------------------------------------------------
