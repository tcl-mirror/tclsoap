#! /bin/sh
#
# ftpserver.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sf.net>
#
# Sample SOAP FTP endpoint.
#
# SOAP over FTP is most likely to be useful for one-way messaging. For
# instance, passing batches of transactions to a processing service. Hence,
# this sample doesn't attempt to pass any reply back to the client.
#
# You can use this with TclSOAP clients by setting the proxy to an
# ftp URL like ftp://anonymous:guest@localhost/soap
# So:
#  package require SOAP::ftp
#  source samples/soap-methods-client.tcl
#  test::init ftp://anonymous:guest@localhost/soap
#  test::platform
#
# $Id$
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the file 'license.terms' for
# more details.
# -------------------------------------------------------------------------
# \
exec wish8.3 "$0" ${1+"$@"}

package require ftpd;                   # tcllib 1.1
package require Memchan 2.2;            # memchan
package require SOAP::CGI

# -------------------------------------------------------------------------
# Configure for our SOAP::CGI installation
set SOAP::CGI::soapmapfile [file join [pwd] .. cgi-bin soapmap.dat]
set SOAP::CGI::soapdir   [file join [pwd] .. cgi-bin soap]

set SOAP::CGI::xmlrpcmapfile [file join [pwd] .. cgi-bin xmlrpcmap.dat]
set SOAP::CGI::xmlrpcdir [file join [pwd] .. cgi-bin soap]

set SOAP::CGI::debugging 1

# -------------------------------------------------------------------------
# The SOAP endpoint handler code

proc ::SOAP::ftpd::endpoint {xml} {
    set doc [dom::DOMImplementation parse [SOAP::CGI::do_encoding $xml]]
    if {[SOAP::CGI::selectNode $doc "/Envelope"] != {}} {
        catch {SOAP::CGI::soap_call $doc} result
    } elseif {[SOAP::CGI::selectNode $doc "/methodCall"] != {}} {
        catch {SOAP::CGI::xmlrpc_call $doc} result
    } else {
        return -code error "invalid protocol:\
            the XML data is neither SOAP nor XML-RPC"
    }

    puts "$result"
    return $result
}

# -------------------------------------------------------------------------

namespace eval ::SOAP::ftpd {
    variable id

    if {![info exists id]} {
        set id 0
    }
}

proc ::SOAP::ftpd::authUsr {user passwd} {
    variable id
    return 1
}

proc ::SOAP::ftpd::authFile {user path op} {
    if {$op == "write" || $op == "append"} {
        return 1
    } else {
        return 0
    }
}

proc ::SOAP::ftpd::fsCmd {cmd path args} {
    switch -exact -- $cmd {
        store - append {
            foreach {input output} [fifo2] {}
            fconfigure $input -translation [lindex $args 0]
            fconfigure $output -translation [lindex $args 0]
            fileevent $output readable \
                [list [namespace current]::Input $output]
            return $input
        }
        default {
            return [::ftpd::fsFile::fs $cmd $path $args]
        }
    }
}

proc ::SOAP::ftpd::Input {chan} {
    variable _$chan
    if {[eof $chan]} {
        close $chan

        # Do something with the data!!
        endpoint [set _$chan]
        unset _$chan

        return
    }
    append _$chan [read $chan]
    return
}

ftpd::config -authUsrCmd ::SOAP::ftpd::authUsr \
        -authFileCmd ::SOAP::ftpd::authFile \
        -fsCmd ::SOAP::ftpd::fsCmd

if {$::tcl_interactive} {
    puts "You probably want to type \"ftpd::server\" now."
} else {
    ftpd::server
}

#
# Local variables:
#  mode: tcl
#  indent-tabs-mode: nil
# End:
