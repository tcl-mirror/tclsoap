# xpath.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Provide a _SIGNIFICANTLY_ simplified version of XPath querying for DOM
# document objects. This might get expanded to eventually conform to the
# W3Cs XPath specification but at present this is purely for use in querying
# DOM documents for specific elements.
#
# Subject to interface changes
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide xpath 0.1

package require dom 1.6

namespace eval xpath {
    variable version 0.1
    variable rcsid { $Id: xpath.tcl,v 1.2 2001/02/26 12:41:04 pt111992 Exp pt111992 $ }
    namespace export xpath
}

# -------------------------------------------------------------------------

# Given Envelope/Body/Fault and a DOM node, see if we can find a matching
# element else return {}

# TODO: Paths including attribute selection etc.

proc xpath::xpath { args } {
    if { [llength $args] < 2 || [llength $args] > 3 } {
        error "wrong # args: should be \"xpath ?option? rootNode path\""
    }

    array set opts {
        -node        0
        -name        0
        -attributes  0
    }

    if { [llength $args] == 3 } {
        set opt [lindex $args 0]
        switch -glob -- $opt {
            -nod*   { set opts(-node) 1 }
            -nam*   { set opts(-name) 1 }
            -att*   { set opts(-attributes) 1 }
            default {
                error "bad option \"$opt\": must be [array names opts]"
            }
        }
        set args [lrange $args 1 end]
    }

    set root [lindex $args 0]
    set path [lindex $args 1]

    foreach nodeName [split $path {/}] {
        if { $nodeName == {} } {
            continue
        }
        set root [find_node $root $nodeName]
        if { $root == {}} {
            return -code error "$nodeName not found"
        }
    }

    # return the elements value (if any)
    if { $opts(-node) } {
        return $root
    }

    set value {}
    if { $opts(-attributes) } {
        foreach node $root {
            append value [array get [dom::node cget $node -attributes]]
        }
        return $value
    }

    if { $opts(-name) } {
        foreach node $root {
            lappend value [dom::node cget $node -nodeName]
        }
        return $value
    }

    foreach node $root {
        set children [dom::node children $node]
        set v ""
        foreach child $children {
            append v [trim [dom::node cget $child -nodeValue]]
        }
        lappend value $v
    }
    return $value
}

# -------------------------------------------------------------------------

# check for an element called name that is a child of root. Returns
# the node, or null
proc xpath::find_node { root name } {
    set r {}
    set kids ""
    foreach element $root { 
        append kids [child_elements $element]
    }
    foreach {node namespace elt_name} $kids {
        if { [string match $name $elt_name] } {
            lappend r $node
        }
    }
    return $r
}

# -------------------------------------------------------------------------

# remove extraneous whitespace from each end of string
proc xpath::trim { str } {
    set r {}
    regsub {^\s+} $str {} r
    regsub {\s+$} $r   {} r
    return $r
}

# -------------------------------------------------------------------------

# Return list of {node namespace elementname} for each child element of root
proc xpath::child_elements { root } {
    set kids {}
    set children [dom::node children $root]
    foreach node $children {
        set type [trim [dom::node cget $node -nodeType ]]
        if { $type == "element" } {
            set name [split [trim [dom::node cget $node -nodeName]] {:}]
            if { [llength $name] == 1 } {
                set ns {}
            } else {
                set ns   [lindex $name 0]
                set name [join [lrange $name 1 end] {:}]
            }
            lappend kids $node $ns $name
        }
    }
    return $kids
}

# -------------------------------------------------------------------------

# Local variables:
#   indent-tabs-mode: nil
# End:
