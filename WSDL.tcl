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
package require SOAP::Schema;           # TclSOAP 1.6.7

namespace eval ::SOAP::WSDL {
    variable version 1.0
    variable rcsid {$Id: wsdl.tcl,v 1.1.1.1 2005/09/09 22:24:17 patthoyts Exp $}
    variable logLevel warning
    
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
            soapenc http://schemas.xmlsoap.org/soap/encoding/
            soapenv http://schemas.xmlsoap.org/soap/envelope/
            xsi     http://www.w3.org/2000/10/XMLSchema-instance
            xsd     http://www.w3.org/2000/10/XMLSchema
        }
    }
}

proc ::SOAP::WSDL::loadWSDL {url} {
    set base [SOAP::Utils::baseurl $url]
    set wsdl [SOAP::Utils::get_url $url]
    set doc [dom::DOMImplementation parse $wsdl]
    set r [parse $doc $base]
    catch {dom::DOMImplementation destroy $doc}

    # FIX ME: this is just odd.
    if {[catch {uplevel #0 [set $r]} msg]} {
        return -code error "failed to load document: $msg"
    }
    return [set SOAP::WSDL::output]
}

proc ::SOAP::WSDL::parse {doc {baseurl {}}} {
    variable URI
    variable output
    set output ""

    foreach node [getElements $doc] {
        if {[string match $URI(wsdl):definitions [qualifyNodeName $node]]} {
            parse_definitions $node $baseurl
        }
    }

    return [namespace which -variable output]
}

proc ::SOAP::WSDL::parse_definitions {Node Base} {
    variable URI
    variable types
    variable messages
    variable portTypes
    variable output

    catch {unset types}
    catch {unset output}    
    catch {unset messages}
    catch {unset portTypes}

    # namespaces

    array set types {}
    foreach typeNode [getElementsByName $Node types] {
        log::log debug "type $typeNode [getElementName $typeNode]"
        parse_types $Node $typeNode $Base
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
proc ::SOAP::WSDL::parse_service {defNode serviceNode} {
    variable types

    set serviceName [getElementAttribute $serviceNode name]   
    output "namespace eval $serviceName {"

    # This is all a bit bogus. We need better handling of the schema type.
    if {[info exists types(.)]} {
        foreach {xsd tns} $types(.) break
    } else {
        set xsd [lindex [splitQName [qualify $defNode xsd:string]] 0]
    }
    if {[string length $xsd] < 1} { set xsd http://www.w3.org/2001/XMLSchema }
    output "  variable schema_version $xsd"

    foreach {name value} [array get types] {
        if {[string equal $name .]} continue
        foreach {type typens value} $value break
        switch -exact -- $type {
            enumeration {
                output "  rpcvar::typedef -namespace \"$typens\" -enum [list $value] $name"
            }
            default {
                output "  rpcvar::typedef -namespace \"$typens\" $value $name"
            }
        }
    }

    foreach portNode [getElementsByName $serviceNode port] {
        parse_port $defNode $portNode
    }
    output "}; # end of $serviceName"
    return 0
}

proc ::SOAP::WSDL::parse_port {defNode portNode} {
    set portName [baseQName [getElementAttribute $portNode name]]
    set portBinding [baseQName [getElementAttribute $portNode binding]]
#    log::log debug "port name=$portName binding=$portBinding"
    
    # process the address elements to find concrete endpoints.
    foreach addressNode [getElements $portNode] {
        if {[string match address \
                 [baseQName [getElementName $addressNode]]]} {
            set transport [namespaceURI $addressNode]
            set location  [getElementAttribute $addressNode location]
            output "  variable endpoint $location\n  variable transport $transport"
        }
    }

    # Find the correct binding element
    foreach bindingNode [getElementsByName $defNode binding] {
        set bindingName [baseQName [getElementAttribute $bindingNode name]]
        if {[string match $bindingName $portBinding]} {
            parse_binding $defNode $bindingNode
        }
    }

    return 0
}

proc ::SOAP::WSDL::parse_binding {defNode bindingNode} {
    # interested in binding style, transport and the operation tags.
    variable portTypes
    variable messages
    variable URI
    set soapStyle document
    set soapTransport {}
    
    set bindingName [getElementAttribute $bindingNode name]
    set bindingType [qualifyTarget $bindingNode [getElementAttribute $bindingNode type]]

    foreach node [getElements $bindingNode] {
        # lets look for WSDL extensions - esp. SOAP extensions.
        switch -exact -- [nodeName $node] {
            binding {
                if {[string match $URI(soap) [namespaceURI $node]]} {
                    if {[set style [getElementAttribute $node style]] != {}} {
                        set soapStyle $style
                    }
                    set soapTransport [getElementAttribute $node transport]
                }
            }
            operation {
                set opname [qualify $node [getElementAttribute $node name]]
                set opbase [baseQName $opname]
                set soapAction {}
                set soapParams {}
                set encoding {}
                set uri {}
                set inputType $portTypes($bindingType,$opname,input)
                set inputMsg $messages([lindex $inputType 1])

                foreach paramNode [getElements $node] {
                    switch -exact -- [set paramNodeName [nodeName $paramNode]] {
                        operation {
                            set soapop [qualifyNodeName $paramNode]
                            if {[string equal $URI(soap):operation $soapop]} {
                                set soapAction \"[getElementAttribute $paramNode soapAction]\"
                            }
                        }
                        input {
                            # body namespace and encoding
                            foreach subnode [getElements $paramNode] {
                                set qual [qualifyNodeName $subnode]
                                if {[string match $URI(soap):body $qual]} {
                                    set use [getElementAttribute $subnode use]
                                    if {[string equal $use "literal"]} {
                                        log::log notice "op $inputMsg"
                                    } else {
                                        set encoding [getElementAttribute $subnode encodingStyle]
                                        set uri      [getElementAttribute $subnode namespace]
                                        foreach {paramName paramType} $inputMsg {
                                            foreach {paramNS paramName} [splitQName $paramName] break
                                            foreach {typeNS typeName} [splitQName $paramType] break
                                            #if {[string equal $typeNS $URI(xsd)]} { set paramType $typeName }
                                            lappend soapParams $paramName $typeName;#$paramType
                                        }
                                    }
                                    log::log notice "operation $opbase $encoding $uri $use $opname"
                                }
                            }
                        }
                        output {
                            # we do not care for client code.
                        }
                    }
                }

                set op_code "  SOAP::create $opbase -proxy \$endpoint\
                        -version SOAP1.1 -schemas \[list xsd \$schema_version\]\
                        -params {$soapParams}"
                if {[string length $soapAction] > 0} {
                    append op_code " -action $soapAction"
                }
                if {[string length $uri] > 0} {
                    append op_code " -uri $uri"
                }
                if {[string length $encoding] < 1} {
                    set encoding $URI(soapenc)
                }
                append op_code " -encoding $encoding"
                output $op_code
            }
        }
    }
    if {[string length $soapTransport] < 1} {
        log::log error "invalid SOAP binding: no soap:binding element seen"
    }
    return 0
}

proc ::SOAP::WSDL::parse_message {definitionsNode messageNode arrayName} {
    upvar $arrayName messages
    set name [qualifyTarget $messageNode [getElementAttribute $messageNode name]]
    set params {}
    foreach part [getElementsByName $messageNode part] {
        set paramName [qualifyTarget $part [getElementAttribute $part name]]
        set eltattr [getElementAttribute $part element]
        set type [getElementAttribute $part type]
        if {[string length $eltattr] > 0} {
            set paramType [qualifyTarget $part $eltattr]
            lappend params $paramName $paramType
        } elseif {[string length $type] > 0} {
            set paramType [qualifyTarget $part $type]
            lappend params $paramName $paramType
        } else {
            log::log debug "parse_message '$paramName'"
        }
    }
    set messages($name) $params
    #log::log debug "method $name -params {$params}"
    return 0
}

proc ::SOAP::WSDL::parse_portType {definitionsNode portTypeNode arrayName} {
    upvar $arrayName portTypes
    set portName [qualifyTarget $portTypeNode [getElementAttribute $portTypeNode name]]
    foreach opNode [getElementsByName $portTypeNode operation] {
        set opName [qualify $opNode [getElementAttribute $opNode name]]

        set node [lindex [getElementsByName $opNode input] 0]
        set name [qualify $node [getElementAttribute $node name]]
        set message [qualify $node [getElementAttribute $node message]]
        set portTypes($portName,$opName,input) [list $name $message]

        set node [lindex [getElementsByName $opNode output] 0]
        set name [qualify $node [getElementAttribute $node name]]
        set message [qualify $node [getElementAttribute $node message]]
        set portTypes($portName,$opName,output) [list $name $message]
        
#        log::log debug "operation: $opName {$portTypes($opName,input) $portTypes($opName,output)}"
    }
    return 0
}

proc ::SOAP::WSDL::parse_types {definitionsNode typesNode baseUrl} {
    variable types
    foreach schemaNode [getElements $typesNode] {
        if {[string equal [nodeName $schemaNode] "schema"]} {
            # element namespace will be the schema we are using
            # targetNamespace is where all our types should go.
            set xsd [namespaceURI $schemaNode]
            set tns [targetNamespaceURI $schemaNode targetNamespace]
            set types(.) [list $xsd $tns]
            set t [::SOAP::Schema::parse $schemaNode $baseUrl]
            foreach typedef $t {
                if {[llength $typedef] < 1} continue
                foreach {typelist typename} $typedef break
                foreach {typename typetag} $typename break
                foreach {typeNS typeName} [splitQName $typename] break
                switch -exact -- $typetag {
                    enum {
                        set types($typeName) [list enumeration $typeNS $typelist]
                    }
                    default {
                        # de-type structure elements
                        set typeList {}
                        foreach {tp nm} [lindex $typelist 0] {
                            lappend typeList [lindex [splitQName $tp] 1] "$nm"
                        }
                        set types($typeName) [list {}          $typeNS [list $typeList]]
                    }
                }
            }
        }
    }
}


proc ::SOAP::WSDL::output {what} {
    variable output
    append output $what "\n"
    log::log debug "$what\n"
}

# -------------------------------------------------------------------------

package provide SOAP::WSDL $SOAP::WSDL::version

# -------------------------------------------------------------------------       
# Local variables:
#    indent-tabs-mode: nil
# End:
