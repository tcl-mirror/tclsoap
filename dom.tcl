# dom.tcl - Copyright (C) 2002 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Wrapper for tDOM 
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

namespace eval SOAP::dom {
    variable rcsid {$Id$}
    variable version 1.0

    namespace export DOMImplementation document node element \
            processingInstruction
    # documentFragment textNode attribute  event

    proc notimplemented {{more {}}} {
        uplevel [list return -code error "command not implemented $more"]
    }
}

proc SOAP::dom::DOMImplementation {method args} {
    switch -- $method {
        hasFeature {
            # bool hasFeature(String feature, String version)
            if {[llength $args] != 2} {
                return -code error "wrong # args"
            }
            set feature [
        }
        
        create {
            
        }
        parse {
            return [eval dom $args]
        }
        serialize {}
        default {
            return -code error "invalid method name \"$method\""
        }
    }
}

proc SOAP::dom::document {method token args} {
    switch -- $method {
        
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

        createElement  -
        createTextNode -
        createComment  -
        createCDATASection {
            return [$token $method [lindex $args 0]]
        }
        createDocumentFragment -
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
            return -code error "invalid method \"$method\""
        }
    }
}

proc SOAP::dom::node {method token args} {
    notimplemented
}

proc SOAP::dom::element {method token args} {
    notimplemented
}

proc SOAP::dom::processinginstruction {method token args} {
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

package provide SOAP::dom $SOAP::dom::version

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
