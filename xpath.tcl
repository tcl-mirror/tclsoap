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

package provide SOAP::xpath 0.1

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

namespace eval SOAP::xpath {
    variable version 0.1
    variable rcsid { $Id: xpath.tcl,v 1.4 2001/03/17 01:19:09 pat Exp pat $ }
    namespace export xpath
}

# -------------------------------------------------------------------------

# Given Envelope/Body/Fault and a DOM node, see if we can find a matching
# element else return {}

# TODO: Paths including attribute selection etc.

proc SOAP::xpath::xpath { args } {
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
    array set xmlns {}
    set nsPath {}

    # split the path up and call find_node to get the new node or nodes.
    foreach nodeName [split $path {/}] {
        if { $nodeName == {} } {
            continue
        }

        ## BUG HERE
        append nsPath "/${nodeName}" ; puts "nsPath: $nsPath"
        xmlnsUpdate xmlns $root $nsPath ; puts "[array get xmlns]"

        set root [find_node $root $nodeName xmlns]
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
proc SOAP::xpath::find_node { root name xmlNamespaces } {
    upvar $xmlNamespaces xmlns
    set r {}
    set kids ""
    foreach element $root { 
        append kids [child_elements $element xmlns]
    }
    foreach {node namespace elt_name} $kids {
        if { [string match $name $elt_name] } {
            lappend r $node
        }
    }
    return $r
}

# -------------------------------------------------------------------------

# Return list of {node namespace elementname} for each child element of root
proc SOAP::xpath::child_elements { root xmlNamespaces } {
    upvar $xmlNamespaces xmlns
    set kids {}
    set children [dom::node children $root]
    foreach node $children {
        set type [string trim [dom::node cget $node -nodeType ]]
        if { $type == "element" } {
            #set name [split [string trim [dom::node cget $node -nodeName]] {:}]
            set name [xmlnsQualify xmlns [dom::node cget $node -nodeName]]
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

# read in the attributes for the current path in DOC and update a table
# of namespace names. Used in xmlns_sub.
#
proc SOAP::xpath::xmlnsUpdate {varName doc path} {
    upvar $varName xmlns
    foreach {ns fqns} [array get [dom::node cget $doc -attributes]] {
	set ns [split $ns :]
        puts "  $ns -> $fqns"
	if { [lindex $ns 0] == "xmlns" } {
	    set xmlns([lindex $ns 1]) $fqns
	}
    }
}

# -------------------------------------------------------------------------

# Split an XML element name into its namespace and name parts and return
# a fully qualified XML element name.
# xmlnsArray is the set of xmlns definitions that have been seen so
# far (see get_xmlns)
#
proc SOAP::xpath::xmlnsQualify {xmlnsNamespaces elementName} {
    upvar $xmlnsNamespaces xmlns
    set name [split $elementName :]

    if { [llength $name] != 2} {
	error "wrong # elements: name should be namespaceName:elementName"
    }

    if { [catch {set fqns $xmlns([lindex $name 0])}] } {
	error "invalid namespace name: \"[lindex $name 0]\" not found"
    }

    set name [lindex $name 1]

    return "${fqns}:${name}"
}

# -------------------------------------------------------------------------

# Local variables:
#   indent-tabs-mode: nil
# End:
