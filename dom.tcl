# dom.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# A wrapper for the tDOM package to make it function as a replacement for
# the TclDOM package.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package require tdom

namespace eval ::SOAP::dom {
    variable rcsid {$Id: dom.tcl,v 1.1.2.2 2003/02/01 00:37:24 patthoyts Exp $}
    variable version 1.0

    namespace export DOMImplementation document node element \
            processingInstruction
    # documentFragment textNode attribute  event

    proc notimplemented {{more {}}} {
        uplevel [list return -code error "command not implemented $more"]
    }
}

# create a DOM document with a named root element.
# Must return a document object
proc ::SOAP::createDocument {name} {
    return [dom createDocument $name]
}

proc ::SOAP::dom::DOMImplementation {method args} {
    switch -glob -- $method {
        hasFeature {
            # bool hasFeature(String feature, String version)
            return [eval [list dom hasFeature] $args]
        }        
        create {
            return [dom createDocument TclSOAPDocElt]
        }
        destroy {
            return {}
        }
        parse {
            return [eval [list dom parse] $args]
        }
        serialize {
	    if {[llength $args] != 1} {
		error "wrong # args: should be \"serialize tok\""
	    }
	    return [[[lindex $args 0] documentElement] asXML]
        }
        default {
	    return -code error "bad option \"$method\": should be hasFeature,\
		    create, destroy, parse or serialize"
        }
    }
}

proc ::SOAP::dom::document {method token args} {
    switch -glob -- $method {
        
        cget {
            if {[llength $args] != 1} {
                return -code error "wrong # args"
            }
            switch -- $args {
                -doctype {
                    notimplemented
                }
                -implementation {
                    notimplemented
                }
                -documentElement {
                    return [$token documentElement]
                }
                default {
                    return -code error "invalid document property:\
                            \"$args\" is not recognised"
                }
            }
        }
	configure {error "notimpl"}

        createElement {
	    set elt [$token createElement $args]
	    return [[$token documentElement] appendChild $elt]
        }
        createTextNode -
        createComment  -
        createCDATASection {
            return [$token $method [lindex $args 0]]
        }
        createDocumentFragment -
        createDocTypeDecl -
        createEntity -
        createEntityReference -
        createAttribute {
            notimplemented "by tdom 0.7"
        }
        createProcessingInstruction {
            if {[llength $args] != 2} {
                return -code error "wrong # args"
            }
            return [$token $method [lindex $args 0] [lindex $args 1]]
        }
        getElementsByTagName {
            return [$token $method [lindex $args 0]]
        }
        default {
	    return -code error "bad option \"$method\": should be cget,\
		    configure, createElement, createDocumentFragment,\
		    createTextNode, createComment, ..."
        }
    }
}

proc ::SOAP::dom::node {method token args} {
    switch -glob -- $method {
	cg* {error "cget notimpl"}
	co* {error "configure notimpl"}
	in* {error "insertbefore notimpl"}
	rep* {error "replaceChild notimpl"}
	rem* {error "removeChild notimpl"}
	ap* {error "appendChild notimpl"}
	hasChildNodes {error "notimpl"}
	cl* {error "cloneNode notimpl"}
	ch* {error "children notimpl"}
	pa* {error "parent notimpl"}
	default {
	    return -code error "bad option \"$method\": should be cget,\
		    configure, ..."
	}
    }
}

proc ::SOAP::dom::element {method token args} {
    switch -glob -- $method {
	default {
	    return -code error "not implmented"
	}
    }
}

proc ::SOAP::dom::processinginstruction {method token args} {
    switch -- $method {
        cget {
            set prop [lindex $args 0]
            switch -- $prop {
                -data {
                    return [$token data]
                }
                -target {
                    return [$token target]
                }
                default {
                    return -code error "invalid property \"$prop\""
                }
            }
        }
        default {
            return -code error "invalid method \"$method\""
        }
    }
}

# -------------------------------------------------------------------------

package provide ::SOAP::dom $SOAP::dom::version

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
