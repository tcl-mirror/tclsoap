# ftp.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide an FTP based transport for the SOAP package.
#
# This is somewhat less complete that the HTTP and SMTP transports.
#
# e.g.:
#   SOAP::create purchase \
#          -proxy ftp://me:passwd@localhost/soapstore/transactions
#          -action urn:tclsoap:Purchase
#          -uri urn:tclsoap:Purchase
#          -params {code string auth string}
#          -command error
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package require ftp;                    # tcllib

namespace eval SOAP::Transport::ftp {
    variable version 1.0
    variable rcsid {$Id$}
    variable options
    
 ##   package provide SOAP::ftp $version

    SOAP::register ftp [namespace current]

    if {![info exists options]} {
        array set options [list \
            headers  {} \
            auth     "$::tcl_platform(user)@[info hostname]" \
        ]
    }

    #proc ::ftp::DisplayMsg {handle msg state} {
    #    # log
    #}       
}

# -------------------------------------------------------------------------

# Description:
#   Permit configuration of the FTP transport.
#
proc SOAP::Transport::ftp::configure {args} {
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
            -auth {
                set options(auth) $value
            }
            -headers {
                set options(headers) $value
            }
            default {
                error "invalid option \"$opt\": must be \
                      \"-auth\" or \"-headers\""
            }
        }
    }
}

# -------------------------------------------------------------------------

# Description:
#
proc SOAP::Transport::ftp::xfer {procVarName url soap} {
    variable options

    array set u [uri::split $url]

    set tok [ftp::Open $u(host) $u(user) $u(pwd)]
    set r [ftp::Append $tok -data $soap $u(path)]
    ftp::Close $tok

    if {! $r} {
        error "SOAP transport error: $r"
    }

    return {}
}

# -------------------------------------------------------------------------

# Description:
#  Called to release any retained resources from a SOAP method.
# Parameters:
#  methodVarName - the name of the SOAP method configuration array
#
proc SOAP::Transport::ftp::cleanup {methodVarName} {
    upvar $methodVarName procvar
    #if {[info exists procvar(http)] && $procvar(http) != {}} {
    #    catch {::http::cleanup $procvar(http)}
    #}
}

# -------------------------------------------------------------------------

#proc SOAP::Transport::ftp::dump {methodName type} {
#}

# -------------------------------------------------------------------------
# Local variables:
#    mode: tcl
#    indent-tabs-mode: nil
# End:
