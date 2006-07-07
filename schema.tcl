# schema.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sf.net>
#
# Process XML Schema documents for WSDL types
# http://www.w3.org/TR/2001/REC-xmlschema-1-20010502/
#
#
#
# See:
# http://www.ruby-lang.org/cgi-bin/cvsweb.cgi/lib/soap4r/lib/wsdl/xmlSchema/
#
# We need to be able to fix the namespace name for xsi builtin types.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package require log;                    # tcllib 1.0
package require uri;                    # tcllib 1.0
package require SOAP::Utils;            # TclSOAP

namespace eval ::SOAP::Schema {
    variable version 0.1
    variable rcsid {$Id: schema.tcl,v 1.1.1.1 2005/09/09 22:24:14 patthoyts Exp $}

    catch {namespace import -force [namespace parent]::Utils::*}
}

# -------------------------------------------------------------------------

# called with the <schema> DOM element
proc ::SOAP::Schema::parse {schemaNode baseUrl} {
    set defs {}
    log::log notice "parsing schema with base $baseUrl"
    foreach typeNode [getElements $schemaNode] {
        # now shift to XML schema parser...
        switch -exact -- [set def [nodeName $typeNode]] {
            annotation  {}
            complexType { lappend defs [parse_complexType $typeNode] }
            simpleType  { lappend defs [parse_simpleType $typeNode] }
            element     { lappend defs [parse_content $typeNode] }
            sequence    { lappend defs [parse_content $typeNode] }
            import  {
                set ns [getElementAttribute $typeNode namespace]
                set loc [getElementAttribute $typeNode schemaLocation]
                if {[string length $loc] > 0} {
                    set loc [SOAP::Utils::normalize_url $loc $baseUrl]
                    log::log notice "schema import '$ns' from '$loc'"
                    set c [import $loc]
                    log::log notice "schema import '$c'"
                    #namespace=urn schemaLocation=url
                }
            }
            default {
                log::log warning "unrecognised schema type:\
                        \"$def\" not handled"
            }
        }
    }
    return $defs
}

proc SOAP::Schema::import {url} {
    set baseUrl [SOAP::Utils::baseurl $url]
    set data [SOAP::Utils::get_url $url]
    set doc [dom::DOMImplementation parse $data]
    set r [parse [dom::document cget $doc -documentElement] $baseUrl]
    dom::DOMImplementation destroy $doc
    return $r
}

# http://www.w3.org/TR/2001/REC-xmlschema-1-20010502/#Simple_Type_Definitions
proc SOAP::Schema::parse_simpleType {typeNode} {
    set typeName [getElementAttribute $typeNode name]
    set typeNamespace [targetNamespaceURI $typeNode $typeName]
    log::log debug "simpleType $typeName"
    foreach node [getElements $typeNode] {
        switch -exact -- [set style [nodeName $node]] {
            restriction {
                # this may be a restricted form of a base type (minInclusive, maxInclusive,
                # pattern or a enumeration set
                # FIX ME: check the specs
                if {[llength [selectNode $node enumeration]] > 0} {
                    set base [qualify $node [getElementAttribute $node base]]
                    set r {}
                    foreach subnode [getElements $node] {
                        lappend r [parse_content $subnode]
                    }
                    set rr [list $r [list $typeNamespace:$typeName enum]]
                    log::log notice "restriction '$rr'"
                    return $rr
                } else {
                    log::log warning "restriction type \"$style\" not supported"
                }
            }
            list -
            union {
                log::log debug "$typeName -> $style"
            }
            annotation {}
            default {
                log::log warning "simple type: \"$style\" not supported"
            }
        }
    }
}

# http://www.w3.org/TR/2001/REC-xmlschema-1-20010502/#Complex_Type_Definitions
proc SOAP::Schema::parse_complexType {typeNode} {
    set typeName [getElementAttribute $typeNode name]

    set types {}
    foreach contentNode [getElements $typeNode] {
        set parsed [parse_content $contentNode]
        log::log debug "parse_complexType < $parsed >"
        lappend types $parsed
    }
    return [list $types [qualify $typeNode $typeName]]
}

proc SOAP::Schema::parse_content {contentNode} {
    set contentName [nodeName $contentNode]
    log::log debug "parse_content $contentNode $contentName"
    switch -exact -- $contentName {
        complexContent -
        all {
            set r {}
            foreach node [getElements $contentNode] {
                set r [concat $r [parse_content $node]]
            }
            return $r
        }
        restriction {
            set base [getElementAttribute $contentNode base]
            set base [qualify $contentNode $base]
            set r {}
            foreach node [getElements $contentNode] {
                set r [concat $r [parse_content $node]]
            }
            return [concat $base $r]
        }
        attribute {
            log::log debug "content attribute" 
        }
        sequence { 
            log::log debug "content sequence" 
#            return [parse $contentNode {}]
        }
        choice { log::log debug "content choice" }
        element {
            set name [getElementAttribute $contentNode name]
            set type [getElementAttribute $contentNode type]
            set r [list [qualify $contentNode $type] $name]
#            puts stderr $r
#            lappend r [parse $contentNode {}]
#            puts stderr $r
#            log::log debug "parse_content $contentNode $name $type"
            return $r
        }
        enumeration {
            return [getElementAttribute $contentNode value]
        }
        annotation {}
        default { log::log warning "unrecognised node \"$contentName\" in complex type"}
    }
    return {}
}

# -------------------------------------------------------------------------

proc ::SOAP::Schema::element {element} {
    array set elt {name {} type {} maxOccurs 1 minOccurs 1 nillable 0\
                       children {}}
    set elt(name) [getElementName $elt]
    if {[string equal [parent type] all] && value != 1} {
        return -code error "invalid attribute"
    }
    set elt(maxOccurs) $maxOccurs
}

# -------------------------------------------------------------------------

package provide SOAP::Schema $::SOAP::Schema::version

# -------------------------------------------------------------------------
# Local variables:
#    indent-tabs-mode: nil
# End:
