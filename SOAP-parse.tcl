# soap-parse.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Parse a SOAP reply packet. Returns a list of XPath(ish) style element paths
# and the value (if there was a value).
#
# Used by SOAP until I work out how to read the packets using DOM.
#
# @(#)$Id: SOAP-parse.tcl,v 1.6 2001/04/19 00:08:37 pat Exp pat $

package provide SOAP::Parse 1.0

if { [catch {package require xml 2.0} msg] } {
    if { [catch {package require xml 1.3} msg] } {
	error "required package missing: xml later than version 1.3 needed"
    }
}

# -------------------------------------------------------------------------

namespace eval SOAP::Parse {
    variable elt_path {}
    variable elt_data
    variable elt_indx
    variable parser

    set parser [xml::parser soap \
            -elementstartcommand  SOAP::Parse::elt_start \
            -elementendcommand    SOAP::Parse::elt_end \
            -characterdatacommand SOAP::Parse::elt_data ]
    
    namespace export parse
}

# -------------------------------------------------------------------------

proc SOAP::Parse::parse { data } {
    variable elt_data
    variable parser

    set elt_data {}
    $parser parse $data
    
    set r {}
    foreach { key val } $elt_data {
	lappend r $val 
    }
    if {[llength $r] == 1} { set r [lindex $r 0] }
    return $r
}

# -------------------------------------------------------------------------

proc SOAP::Parse::elt_start { name attributes args } {
    variable elt_path
    variable elt_indx
    variable elt_data
    set elt_indx [llength $elt_data]
    lappend elt_path $name
}

# -------------------------------------------------------------------------

proc SOAP::Parse::elt_end { name args } {
    variable elt_path
    set elt_path [lreplace $elt_path end end ]
}

# -------------------------------------------------------------------------

proc SOAP::Parse::elt_data data {
    variable elt_path
    variable elt_data
    variable elt_indx

    set d {}
    set ndx [expr $elt_indx + 1]

    if { ! [regexp {^[ \t\n]*$} $data] } {
	set path [join $elt_path {/}]

        set d [lindex $elt_data $ndx]
        append d $data
        if { [llength $elt_data] <= $elt_indx } {
            lappend elt_data $path $d
        } else {
            set elt_data [lreplace $elt_data $ndx $ndx $d]
        }
    }
}

# -------------------------------------------------------------------------

#
# Local variables:
#   indent-tabs-mode: nil
# End:
