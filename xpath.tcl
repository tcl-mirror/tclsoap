# xpath.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
#

package provide xpath 0.1

package require dom 1.6

namespace eval xpath {
    variable version 0.1
    variable rcsid { $Id$ }
    namespace export xpath
}

# Given Envelope/Body/Fault and a DOM node, see if we can find a matching
# element else return {}
proc xpath::xpath { root path } {
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
    set tnode [dom::node cget $root -firstChild]
    set value [trim [dom::node cget $tnode -nodeValue]]
    return $value
}

# check for an element called name that is a child of root. Returns
# the node, or null
proc xpath::find_node { root name } {
    set kids [child_elements $root]
    foreach {node namespace elt_name} $kids {
        if { $elt_name == $name } {
            return $node
        }
    }
    return {}
}

# remove extraneous whitespace from each end of string
proc xpath::trim { str } {
    set r {}
    regsub {^\s+} $str {} r
    regsub {\s+$} $r   {} r
    return $r
}

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

# Local variables:
#   indent-tabs-mode: nil
# End:
