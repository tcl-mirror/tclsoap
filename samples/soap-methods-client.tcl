# soap-methods-client.tcl 
#                  - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
#  Setup the client side of the sample services provided through the
#  SOAP::Domain package.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id: soap-methods-client.tcl,v 1.2 2001/07/16 23:39:51 patthoyts Exp $

package require SOAP

# Description:
#   Setup the client methods for our sample services. Optionally specify the
#   serving host.
#
proc define_domain_methods {{proxy http://localhost:8015/soap}} {
    set uri urn:tclsoap-Test
    set methods {}

    set name rcsid
    lappend methods [ SOAP::create $name -name rcsid -uri $uri \
	    -proxy "${proxy}/${name}" -params {} ]
    
    set name zbase64
    lappend methods [ SOAP::create $name -name base64 -uri $uri \
	    -proxy "${proxy}/base64" -params {msg string} ]

    set name ztime
    lappend methods [ SOAP::create $name -name time -uri $uri \
	    -proxy "${proxy}/time" -params {} ]
    
    set name square
    lappend methods [ SOAP::create $name -name square -uri $uri \
	    -proxy "${proxy}/${name}" -params {num double} ]
    
    set name sum
    lappend methods [ SOAP::create $name -name sum -uri $uri \
	    -proxy "${proxy}/${name}" -params {lhs double rhs double} ]

    set name sort
    lappend methods [ SOAP::create $name -name sort -uri $uri \
	    -proxy "${proxy}/${name}" -params {myArray array} ]

    set name platform
    lappend methods [ SOAP::create $name -name platform -uri $uri \
	    -proxy "${proxy}/${name}" -params {} ]

    set name xml
    lappend methods [ SOAP::create $name -name xml -uri $uri \
	    -proxy "${proxy}/${name}" -params {} ]
	
    return $methods
}

define_domain_methods

# -------------------------------------------------------------------------
#
# Local variables:
# mode: tcl
# End:
