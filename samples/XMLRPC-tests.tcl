# XMLRPC-tests.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Create some remote XML-RPC access methods to demo servers.
#
# If you live behind a firewall and have an authenticating proxy web server
# try executing SOAP::proxyconfig and filling in the fields. This sets
# up the SOAP package to send the correct headers for the proxy to 
# forward the packets (provided it is using the `Basic' encoding scheme).
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id$

package require XMLRPC

set methods {}

# -------------------------------------------------------------------------

# Local test services (fromXMLRPC-domain.tcl)

lappend methods [ \
    XMLRPC::create rand \
        -name "zsplat.rand" \
        -proxy "http://localhost:8015/xmlrpc/rand" \
        -params {} ]

lappend methods [ \
    XMLRPC::create xtest \
        -name "zsplat.xtest" \
        -proxy "http://localhost:8015/xmlrpc/xtest" \
        -params { names array(string) } ]
        

# -------------------------------------------------------------------------

# Some of UserLands XML RPC examples.

lappend methods [ \
    XMLRPC::create getStateName \
        -name "examples.getStateName" \
        -proxy "http://betty.userland.com/RPC2" \
        -params { state i4 } ]

lappend methods [ \
    XMLRPC::create getStateList \
	-name "examples.getStateList" \
	-proxy "http://betty.userland.com/RPC2" \
	-params { states array(int) } ]

# -------------------------------------------------------------------------

set methods

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
