# soap-parse.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Parse a SOAP reply packet. Returns a list of XPath(ish) style element paths
# and the value (if there was a value).
#
# Used by SOAP until I work out how to read the packets using DOM.
#
# @(#)$Id: SOAP-parse.tcl,v 1.5 2001/03/26 23:41:47 pat Exp pat $

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
    variable parser

    set parser [xml::parser soap \
            -elementstartcommand  SOAP::Parse::elt_start \
            -elementendcommand    SOAP::Parse::elt_end \
            -characterdatacommand SOAP::Parse::elt_data ]
}

# -------------------------------------------------------------------------

proc SOAP::Parse::parse { data } {
    variable elt_data
    variable parser

    catch { unset elt_data }
    $parser parse $data
    
    set r {}
    foreach { key val } [array get elt_data] {
	append r $val 
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
	append d $data
	set elt_data($path) $d
    }
}

# -------------------------------------------------------------------------

#
# Local variables:
#   indent-tabs-mode: nil
# End:
