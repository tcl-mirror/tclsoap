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
    variable rcsid {$Id: WSDL.tcl,v 1.1.2.4 2003/01/24 01:03:05 patthoyts Exp $}
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
    variable output

    foreach node [getElements $doc] {
        if {[string match $URI(wsdl):definitions [qualifyNodeName $node]]} {
            parse_definitions $node
        }
    }

    return [namespace which -variable output]
}

proc SOAP::WSDL::parse_definitions {Node} {
    variable URI
    variable types
    variable messages
    variable portTypes
    variable output

    catch {unset types}
    catch {unset output}    
    catch {unset messages}
    catch {unset portTypes}

    array set types {}
    foreach typeNode [getElementsByName $Node types] {
        parse_types $Node $typeNode types
    }

    array set messages {}
    foreach messageNode [getElementsByName $Node message] {
        parse_message $Node $messageNode messages
    }

    array set portTypes {}
    foreach portTypeNode [getElementsByName $Node portType] {
        parse_portType $Node $portTypeNode portTypes
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
    output "namespace eval $serviceName {"

    foreach portNode [getElementsByName $serviceNode port] {
        parse_port $defNode $portNode
    }
    output "}; # end of $serviceName"
    return 0
}

proc SOAP::WSDL::parse_port {defNode portNode} {
    set portName [baseElementName [getElementAttribute $portNode name]]
    set portBinding [baseElementName [getElementAttribute $portNode binding]]
#    log::log debug "port name=$portName binding=$portBinding"
    
    # process the address elements to find concrete endpoints.
    foreach addressNode [getElements $portNode] {
        if {[string match address \
                 [baseElementName [getElementName $addressNode]]]} {
            set transport [namespaceURI $addressNode]
            set location  [getElementAttribute $addressNode location]
            output "    set endpoint $location ;# transport=$transport"
        }
    }

    # Find the correct binding element
    foreach bindingNode [getElementsByName $defNode binding] {
        set bindingName [baseElementName [getElementAttribute $bindingNode name]]
        if {[string match $bindingName $portBinding]} {
            parse_binding $defNode $bindingNode
        }
    }

    return 0
}

proc SOAP::WSDL::parse_binding {defNode bindingNode} {
    # interested in binding style, transport and the operation tags.
    variable portTypes
    variable messages
    variable URI
    
    foreach node [getElements $bindingNode] {
        # lets look for WSDL extensions - esp. SOAP extensions.
        switch -exact -- [nodeName $node] {
            binding {
                if {[string match $URI(soap) [namespaceURI $node]]} {
                    set soapStyle [getElementAttribute $node style]
                    set transport [getElementAttribute $node transport]
                }
            }
            operation {
                set opname [qualify $node [getElementAttribute $node name]]
                set opbase [baseName $opname]
                set soapAction {}
                set encoding $URI(soapenc)
                set uri {}
                set inputType $portTypes($opname,input)
                set inputMsg $messages([baseName [lindex $inputType 1]])
                foreach paramNode [getElements $node] {
                    switch -exact -- [nodeName $paramNode] {
                        operation {
                            if {[string match $URI(soap) [namespaceURI $paramNode]]} {
                                set soapAction [getElementAttribute $paramNode soapAction]
                            }
                        }
                        input {
                            # body namespace and encoding
                            foreach subnode [getElements $paramNode] {
                                set qual [namespaceURI $subnode]:[nodeName $subnode]
                                if {[string match $URI(soap):body $qual]} {
                                    set encoding [getElementAttribute $subnode encodingStyle]
                                    set uri      [getElementAttribute $subnode namespace]
                                }
                            }
                        }
                        output {
                            # we do not care for client code.
                        }
                    }
                }

                output "    SOAP::create $opbase -proxy \$endpoint\
                        -params {$inputMsg} -action $soapAction\
                        -encoding $encoding -uri $uri"
            }
        }
    }
    return 0
}

proc SOAP::WSDL::parse_message {definitionsNode messageNode arrayName} {
    upvar $arrayName messages
    set name [getElementAttribute $messageNode name]
    set params {}
    foreach part [getElementsByName $messageNode part] {
        set paramName [getElementAttribute $part name]
        set paramType [qualify $part [getElementAttribute $part type]]
        lappend params $paramName $paramType
    }
    set messages($name) $params
#    log::log debug "method $name -params {$params}"
    return 0
}

proc SOAP::WSDL::parse_portType {definitionsNode portTypeNode arrayName} {
    upvar $arrayName portTypes
    foreach opNode [getElementsByName $portTypeNode operation] {
        set opName [qualify $opNode [getElementAttribute $opNode name]]

        set node [lindex [getElementsByName $opNode input] 0]
        set name [qualify $node [getElementAttribute $node name]]
        set message [qualify $node [getElementAttribute $node message]]
        set portTypes($opName,input) [list $name $message]

        set node [lindex [getElementsByName $opNode output] 0]
        set name [qualify $node [getElementAttribute $node name]]
        set message [qualify $node [getElementAttribute $node message]]
        set portTypes($opName,output) [list $name $message]
        
#        log::log debug "operation: $opName {$portTypes($opName,input) $portTypes($opName,output)}"
    }
    return 0
}

proc SOAP::WSDL::parse_types {definitionsNode typesNode arrayName} {
    upvar $arrayName types
    foreach schemaNode [getElementsByName $typesNode schema] {
        foreach typeNode [getElements $schemaNode] {
            # now shift to XML schema parser...
            switch -exact -- [set def [getElementName $typeNode]] {
                complexType { parse_complexType $typeNode $arrayName}
                simpleType { parse_simpleType $typeNode $arrayName }
                default {
                    log::log warning "unrecognised schema type:\
                        \"$def\" not handled"
                }
            }
        }
    }
    return 0
}

proc SOAP::WSDL::parse_simpleType {typeNode arrayName} {
    set typeName [getElementAttribute $typeNode name]
    log::log debug "simpleType $typeName"
}

proc SOAP::WSDL::parse_complexType {typeNode arrayName} {
    set typeName [getElementAttribute $typeNode name]
    log::log debug "complexType $typeName"

    foreach contentNode [getElements $typeNode] {
        switch -exact -- [set contentName [getElementName $contentNode]] {
            all { xsd:content $contentNode arrayName }
            sequence { log::log debug "content sequence" }
            choice { log::log debug "content choice" }
            complexContent {log::log debug "content complex" }
            attribute { log::log debug "content attribute" }
            default { log::log warning "unrecognised node \"$contentName\""}
        }
    }
}

proc SOAP::WSDL::xsd:content {contentNode arrayname} {
    foreach elt [getElements $contentNode] {
        # must recurse (could be all, sequence or choice again.)
    }
}

proc SOAP::WSDL::qualifyNodeName {node} {
    return [namespaceURI $node]:[getElementName $node]
}

proc SOAP::WSDL::qualifyTarget {node what} {
    return [qualify $node $what 1]
}

proc SOAP::WSDL::qualify {node name {target 0}} {
    set ndx [string last : $name]
    set nodeNS [string trimright [string range $name 0 $ndx] :]
    set nodeBase [string trimleft [string range $name $ndx end] :]
    
    set nodeNS [SOAP::Utils::find_namespaceURI $node $nodeNS $target]
    return $nodeNS:$nodeBase
}

proc SOAP::WSDL::baseName {qualName} {
    return [lindex [split $qualName :] end]
}

proc SOAP::WSDL::output {what} {
    variable output
    append output $what "\n"
}

package provide SOAP::WSDL $SOAP::WSDL::version

# -------------------------------------------------------------------------       
# Local variables:
#    indent-tabs-mode: nil
# End:
