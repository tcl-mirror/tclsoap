# WSDL.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# WSDL specification is at http://www.w3.org/TR/wsdl
#
# You may want to do SOAP::setLogLevel debug while debugging this
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

namespace eval SOAP::WSDL {
    variable version 1.0
    variable rcsid {$Id: WSDL.tcl,v 1.1.2.1 2002/11/07 23:08:00 patthoyts Exp $}
    variable logLevel debug #warning
    
    #namespace export 
    catch {namespace import -force [namespace parent]::Utils::*}

    # WSDL specification constants
    variable URI
    if {![info exists [namespace current]::URI]} {
        array set URI {
            wsdl    http://schemas.xmlsoap.org/wsdl/
            soap    http://schemas.xmlsoap.org/wsdl/soap/
            http    http://schemas.xmlsoap.org/wsdl/http/
            smtp    http://schemas.xmlsoap.org/wsdl/smtp/
            mime    http://schemas.xmlsoap.org/wsdl/mime/
            soapenc http:/schemas.xmlsoap.org/soap/encoding/
            soapenv http:/schemas.xmlsoap.org/soap/envelope/
            xsi     http://www.w3.org/2000/10/XMLSchema-instance
            xsd     http://www.w3.org/2000/10/XMLSchema
        }
    }
}

proc SOAP::WSDL::parse {doc} {
    variable URI
    foreach node [getElements $doc] {
        set qual "[namespaceURI $node]:[getElementName $node]"
        if {[string match "$URI(wsdl):definitions" $qual]} {
            parse_definitions $node
        }
    }
}

proc SOAP::WSDL::parse_definitions {Node} {
    variable URI

    set targetNamespace [getElementAttribute $Node targetNamespace]
    log::log debug "tns $targetNamespace"

    array set messages {}
    foreach messageNode [getElementsByName $Node message] {
        parse_message $Node $messageNode messages
    }

    foreach serviceNode [getElementsByName $Node service] {
        set ns [namespaceURI $serviceNode]
        if {[string match $URI(wsdl) $ns]} {
            parse_service $Node $serviceNode
        } else {
            log::log warning "non WSDL service element found and ignored"
        }
    }
}

# Parse a single service definition
proc SOAP::WSDL::parse_service {defNode serviceNode} {
    set serviceName [getElementAttribute $serviceNode name]
    log::log debug "service $serviceName"

    foreach portNode [getElementsByName $serviceNode port] {
        parse_port $defNode $portNode
    }
    return 0
}

proc SOAP::WSDL::parse_port {defNode portNode} {
    set portName [baseElementName [getElementAttribute $portNode name]]
    set portBinding [baseElementName [getElementAttribute $portNode binding]]
    log::log debug "port name=$portName binding=$portBinding"
    
    # process the address elements to find concrete endpoints.
    foreach addressNode [getElements $portNode] {
        if {[string match address \
                 [baseElementName [getElementName $addressNode]]]} {
            set transport [namespaceURI $addressNode]
            set location  [getElementAttribute $addressNode location]
            log::log debug "address: transport=$transport endpoint=$location"
        }
    }

    # Find the correct binding element
    foreach bindingNode [getElementsByName $defNode binding] {
        set bindingName [baseElementName [getElementAttribute $bindingNode name]]
        log::log debug "binding $bindingName"
        if {[string match $bindingName $portBinding]} {
            log::log debug "matched binding $bindingName"
            parse_binding $defNode $bindingNode
        }
    }

    return 0
}

proc SOAP::WSDL::parse_binding {defNode bindingNode} {
    # interested in binding style, transport and the operation tags.
    foreach node [getElementsByName $bindingNode operation] {
        set qual [namespaceURI $node]:[getElementName $node]
        set opname [getElementAttribute $node name]
        log::log debug ">> $qual $opname"
    }
    return 0
}

proc SOAP::WSDL::parse_types {Node} {
    return 0
}

proc SOAP::WSDL::qualifyName {node name} {
    set ndx [string last : $name]
    set nodeNS [string trimright [string range $name 0 $ndx] :]
    set nodeBase [string trimleft [string range $name $ndx end] :]
    
    set nodeNS [SOAP::Utils::find_namespaceURI $node $nodeNS]
    return $nodeNS:$nodeBase
}
    
proc SOAP::WSDL::parse_message {definitionsNode messageNode arrayName} {
    upvar $arrayName messages
    set name [getElementAttribute $messageNode name]
    set params {}
    foreach part [getElementsByName $messageNode part] {
        set paramName [getElementAttribute $part name]
        set paramType [qualifyName $part [getElementAttribute $part type]]
        lappend params $paramName $paramType
    }
    set messages($name) $params
    log::log debug "method $name -params {$params}"
    return 0
}

proc SOAP::WSDL::parse_portType {definitionsNode portTypeNode} {
    foreach opNode [getElementsByName $portTypeNode operation] {
        set opName [getElementAttribute $opNode name]
        
        log::log debug "operation: $opName"
    }
    return 0
}

package provide SOAP::WSDL $SOAP::WSDL::version

# -------------------------------------------------------------------------       
# Local variables:
#    indent-tabs-mode: nil
# End:
