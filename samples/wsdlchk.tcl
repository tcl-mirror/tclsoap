#! /bin/sh
# -------------------------------------------------------------------------
# Test the SOAP WSDL package.
# -------------------------------------------------------------------------
#
# \
exec tclsh "$0" ${1+"$@"}

package require SOAP 1.6.6
package require SOAP::WSDL

proc wsdlchk {filename} {
    set f [open $filename r]
    set doc [dom::DOMImplementation parse [read $f]]
    close $f
    set code [SOAP::WSDL::parse $doc]
    catch {dom::DOMImplementation destroy $doc}
    return $code
}

if {! $::tcl_interactive} {
    if {[llength $argv] < 1} {
        puts stderr "usage: wsdlchk filename"        
    } else {
        SOAP::setLogLevel debug
        set s [wsdlchk [lindex $argv 0]]
        puts [set $s]
    }
}