# utils.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# DOM data access utilities for use in the TclSOAP package.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide SOAP::Utils 1.0

namespace eval SOAP {
    namespace eval Utils {
        variable rcsid {$Id$}
        namespace export getElements \
                getElementValue getElementName \
                getElementValues getElementNames \
                getElementNamedValues \
                decomposeSoap selectNode
    }
}

# -------------------------------------------------------------------------

# Description:
#   Provide a version independent selectNode implementation. We either use
#   the version from the dom package or use the SOAP::xpath version if there
#   is no dom one.
# Parameters:
#   node  - reference to a dom tree
#   path  - XPath selection
# Result:
#   Returns the selected node or a list of matching nodes or an empty list
#   if no match.
#
proc SOAP::Utils::selectNode {node path} {
    catch {package require dom} domVersion
    if {$domVersion < 2.0} {
	package require SOAP::xpath
        if {[catch {SOAP::xpath::xpath -node $node $path} r]} {
            set r {}
        }
        return $r
    } else {
        return [dom::DOMImplementation selectNode $node $path]
    }
}

# -------------------------------------------------------------------------

# for extracting the parameters from a SOAP packet.
# Arrays -> list
# Structs -> list of name/value pairs.
# a methods parameter list comes out looking like a struct where the member
# names == parameter names. This allows us to check the param name if we need
# to.

proc SOAP::Utils::is_array {domElement} {
    # Look for "xsi:type"="SOAP-ENC:Array"
    if {[catch {
	set [subst [dom::node cget $domElement -attributes](xsi:type)]
    } a]} { set a {} }
    if {[string match -nocase {*:Array} $a] == 1} {
	return 1
    }

    # If all the child element names are the same, it's an array
    # but of there is only one element???
    set names {}
    set elements [getElements $domElement]
    if {[llength elements] > 1} {
        foreach elt [getElements $domElement] {
            lappend names [getElementName $elt]
        }
        set names [lsort -unique $names]
        
        if {[llength $names] == 1} {
            return 1
        }
    }

    return 0
}

# -------------------------------------------------------------------------

proc SOAP::Utils::decomposeSoap {domElement} {
    set result {}

    # get a list of the child elements of this base element.
    set child_elements [getElements $domElement]

    # if no child element - return the value.
    if {$child_elements == {}} {
	set result [getElementValue $domElement]
    } else {
	# decide if this is an array or struct
	if {[is_array $domElement] == 1} {
	    foreach child $child_elements {
		lappend result [decomposeSoap $child]
	    }
	} else {
	    foreach child $child_elements {
		lappend result [getElementName $child] [decomposeSoap $child]
	    }
	}
    }

    return $result
}

# -------------------------------------------------------------------------

# Description:
#   Return a list of all the immediate children of domNode that are element
#   nodes.
# Parameters:
#   domNode  - a reference to a node in a dom tree
#
proc SOAP::Utils::getElements {domNode} {
    set elements {}
    foreach node [dom::node children $domNode] {
        if {[dom::node cget $node -nodeType] == "element"} {
            lappend elements $node
        }
    }
    return $elements
}

# -------------------------------------------------------------------------

# Description:
#   If there are child elements then recursively call this procedure on each
#   child element. If this is a leaf element, then get the element value data.
# Parameters:
#   domElement - a reference to a dom element node
# Result:
#   Returns a value or a list of values.
#

proc SOAP::Utils::getElementValues {domElement} {
    set result {}
    set nodes [getElements $domElement]
    if {$nodes =={}} {
        set result [getElementValue $domElement]
    } else {
        foreach node $nodes {
            lappend result [getElementValues $node]
        }
    }
    return $result
}

proc SOAP::Utils::getElementValuesList {domElement} {
    set result {}
    set nodes [getElements $domElement]
    if {$nodes =={}} {
        set result [getElementValue $domElement]
    } else {
        foreach node $nodes {
            lappend result [getElementValues $node]
        }
    }
    return $result
}

# -------------------------------------------------------------------------

proc SOAP::Utils::getElementNames {domElement} {
    set result {}
    set nodes [getElements $domElement]
    if {$nodes == {}} {
	set result [getElementName $domElement]
    } else {
	foreach node $nodes {
	    lappend result [getElementNames $node]
	}
    }
    return $result
}

# -------------------------------------------------------------------------

proc SOAP::Utils::getElementNamedValues {domElement} {
    set name [getElementName $domElement]
    set value {}
    set nodes [getElements $domElement]
    if {$nodes == {}} {
	set value [getElementValue $domElement]
    } else {
	foreach node $nodes {
	    lappend value [getElementNamedValues $node]
	}
    }
    return [list $name $value]
}

# -------------------------------------------------------------------------

# Description:
#   Merge together all the child node values under a given dom element
# Params:
#   domElement  - a reference to an element node in a dom tree
# Result:
#   A string containing the elements value
#
proc SOAP::Utils::getElementValue {domElement} {
    set r {}
    set dataNodes [dom::node children $domElement]
    foreach dataNode $dataNodes {
        append r [dom::node cget $dataNode -nodeValue]
    }
    return $r
}
# -------------------------------------------------------------------------

proc SOAP::Utils::getElementName {domElement} {
    return [dom::node cget $domElement -nodeName]
}

proc SOAP::Utils::getElementAttributes {domElement} {
    set attr [dom::node cget $domElement -attributes]
    set attrlist [array get $attr]
    return $attrlist
}

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
