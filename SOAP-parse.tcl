# soap-parse.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Parse a SOAP reply packet. Returns a list of XPath style element paths
# and the value (if there was a value).
#
# Used by SOAP until I work out how to read the packets using DOM.
#
# @(#)$Id: SOAP-parse.tcl,v 1.2 2001/02/19 00:44:46 pat Exp pat $

package provide SOAP::Parse 1.0

package require xml

# -------------------------------------------------------------------------

namespace eval SOAP::Parse {
    variable elt_path {}
    variable elt_data
}

# -------------------------------------------------------------------------

proc SOAP::Parse::parse { data } {
    variable elt_data

    catch { unset elt_data }
    catch { xml::parser soapyx \
	    -elementstartcommand  SOAP::Parse::elt_start \
	    -elementendcommand    SOAP::Parse::elt_end \
	    -characterdatacommand SOAP::Parse::elt_data } msg
    set parser ::xml::soapyx
    
    $parser parse $data
    
    set r {}
    foreach { key val } [array get elt_data] {
	lappend r $val 
    }

    return $r
}

# -------------------------------------------------------------------------

proc SOAP::Parse::elt_start { name attributes args } {
    variable elt_path
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
    if { ! [regexp {^[ \t\n]*$} $data] } {
	set path [join $elt_path {/}]
	catch { set d $elt_data($path) } msg
	lappend d $data
	set elt_data($path) $d
    }
}

# -------------------------------------------------------------------------

#
# Local variables:
#   indent-tabs-mode: nil
# End:
