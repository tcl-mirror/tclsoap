# XMLRPC.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide Tcl access to XML-RPC provided methods.
#
# See http://tclsoap.sourceforge.net/ for usage details.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide XMLRPC 1.0

package require SOAP 1.4

namespace eval XMLRPC {
    variable version 1.0
    variable rcs_version { $Id$ }

    namespace export create cget dump configure proxyconfig
}

# -------------------------------------------------------------------------

# Delegate all these methods to the SOAP package. The only difference between
# a SOAP and XML-RPC call is the -xmlrpc flag set on the method variables
# during creation.

proc XMLRPC::create {args } {
    lappend args -xmlrpc 1
    return [uplevel 1 "SOAP::create $args"]
}

proc XMLRPC::configure { args } {
    return [uplevel 1 "SOAP::configure $args"]
}

proc XMLRPC::cget { args } {
    return [uplevel 1 "SOAP::cget $args"] 
}

proc XMLRPC::dump { args } {
    return [uplevel 1 "SOAP::dump $args"] 
}

proc XMLRPC::proxyconfig { args } {
    return [uplevel 1 "SOAP::proxyconfig $args"] 
}

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
