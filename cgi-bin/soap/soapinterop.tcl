# soapinterop.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# The XMethods SOAP Interoperability Lab Test Suite. Round 1.
#
# See http://www.xmethods.net/soapbuilders/proposal.html
#
# General Guidelines:
# * SOAPAction should be present, and quoted. 
#
# * Method namespace should be a well-formed , legal URI 
#
# * Each server implementation is free to use a SOAPAction value and
#   method namespace value of its own choosing.  However, if the
#   implementation has no preference, we suggest using a SOAPAction
#   value of "urn:soapinterop" and a method namespace of
#   "http://soapinterop.org/"
#
# * For this method set, implementations may carry explicit typing
#   information on the wire, but should not require it for incoming
#   messages.
#
# * Since we are dealing strictly with Section 5 encoding, encodingStyle
#   should be present and set to
#   http://schemas.xmlsoap.org/soap/encoding/
#
# * WSDL is NOT required on the server side.  Implementations that
#   require WSDL for binding are responsible for creating it locally on
#   the client.
#
# The SOAPStruct struct is defined as:
# <complexType name="SOAPStruct">
#   <all>
#     <element name="varString" type="xsd:string" />
#     <element name="varInt" type="xsd:int" /> 
#     <element name="varFloat" type="xsd:float" /> 
#   </all>
# </complexType>
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id: soapinterop.tcl,v 1.2 2001/08/28 23:14:01 patthoyts Exp $

package require SOAP
package require rpcvar
namespace import -force rpcvar::*

namespace eval http://soapinterop.org/ {

    # expose the SOAP methods
    SOAP::export echoInteger echoFloat echoString echoStruct \
	    echoIntegerArray echoFloatArray echoStringArray echoStructArray \
	    echoVoid echoDate echoBase64

    typedef -namespace http://soapinterop.org/xsd { \
	    varString string \
	    varInt    int \
	    varFloat  float} SOAPStruct

    proc echoInteger {inputInteger} {
	if {! [string is integer -strict $inputInteger]} {
	    error "invalid arg: \"inputInteger\" must be an integer"
	}
	return $inputInteger
    }
    
    proc echoFloat {inputFloat} {
	if {! [string is double -strict $inputFloat]} {
	    error "invalid arg: \"inputFloat\" must be a float"
	}
	return $inputFloat
    }

    proc echoString {inputString} {
	return $inputString
    }

    proc echoBase64 {inputBase64} {
	return [rpcvar "base64" $inputBase64]
    }

    proc echoDate {inputDate} {
	return [rpcvar "dateTime" $inputDate]
    }

    proc echoVoid {} {
	# handle headers. Any headers destined for us should be removed
	# from the dom tree because later the CGI framework is going to 
	# check and any header with mustUnderstand == 1 && actor == me
	# will throw an exception.

	set header {}
	set headerNode [uplevel 2 set headerNode]

	if {$headerNode != {}} {
	    if {[set node [lindex \
		    [SOAP::selectNode $headerNode "echoMeStringRequest"]\
		    0]] != {}} {
		set actor [SOAP::getElementAttribute $node actor]
		if {$actor == {} || \
			[string match $actor "http://schemas.xmlsoap.org/soap/actor/next"] != 0} {
		    if {[string match "http://soapinterop.org/echoheader/" [SOAP::namespaceURI $node]]} {
			
			lappend header "s:echoMeStringResponse" \
			    [rpcvar -attribute {xmlns:s "http://soapinterop.org/echoheader/"} \
				 string [SOAP::decomposeSoap $node]]
			# having successfully processed the node, delete it
			dom::node removeChild $headerNode $node
		    }
		}
	    } elseif {[set node [SOAP::selectNode $headerNode "echoMeStructRequest"]] != {}} {
		error "Not done."
	    }
	}

	return [rpcvar -header $header int {}]
    }

    proc echoStruct {inputStruct} {
	return [rpcvar SOAPStruct $inputStruct]
    }

    proc echoIntegerArray {inputIntegerArray} {
	return [rpcvar int() $inputIntegerArray]
    }

    proc echoFloatArray {inputFloatArray} {
	return [rpcvar float() $inputFloatArray]
    }

    proc echoStringArray {inputStringArray} {
	return [rpcvar string() $inputStringArray]
    }

    proc echoStructArray {inputStructArray} {
	return [rpcvar SOAPStruct() $inputStructArray]
    }
}

#
# Local variables:
# mode: tcl
# End:
