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
    variable rcsid {$Id$}
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
            log::log debug "address: $transport $location"
        }
    }

    # Find the correct binding element
    foreach bindingNode [getElementsByName $defNode binding] {
        set bindingName [baseElementName [getElementAttribute $bindingNode name]]
        log::log debug "binding $bindingName"
        if {[string match $bindingName $portBinding]} {
            log::log debug "matched binding $bindingName"
            # interested in binding style, transport and the operation tags.
        }
    }

    return 0
}

proc SOAP::WSDL::parse_types {Node} {
    return 0
}

proc SOAP::WSDL::parse_message {Node} {
    set methodName [getElementAttribute $Node name]
    log::log debug "method $methodName"
    return 0
}

proc SOAP::WSDL::parse_portType {Node} {
    return 0
}

proc SOAP::WSDL::parse_binding {Node} {
    return 0
}

package provide SOAP::WSDL $SOAP::WSDL::version

# -------------------------------------------------------------------------       
# Local variables:
#    indent-tabs-mode: nil
# End:
