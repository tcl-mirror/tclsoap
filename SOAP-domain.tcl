# SOAP-domain.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# SOAP Domain Service module for the tclhttpd web server.
#
# Get the server to require the SOAP::Domain package and call 
# SOAP::Domain::register to register the domain handler with the server.
# ie: put the following in a file in tclhttpd/custom
#    package require SOAP::Domain
#    SOAP::Domain::register /soap
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide SOAP::Domain 0.2

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

package require SOAP::xpath

namespace eval SOAP::Domain {
    variable version 0.2  ;# package version number
    variable debug 1      ;# flag to toggle debug output
    variable soapspaces   ;# list of registered namespaces
    variable rcs_id {$Id: SOAP-domain.tcl,v 1.1 2001/04/10 00:21:55 pat Exp pat $}

    namespace import -force [namespace parent]::xpath::*

    namespace export fault reply_envelope reply_simple
}

# -------------------------------------------------------------------------

# Register this package with tclhttpd.
#
#  virtual   url prefix to use (ie: /soap)
#  soapspace namespace to search for the soap method implementation
#  args      any other options
#
proc SOAP::Domain::register {virtual soapspace args} {
    variable soapspaces
    Url_PrefixInstall $virtual [list SOAP::Domain::domain_handler] $args
    lappend soapspaces $soapspace
}

# -------------------------------------------------------------------------

# SOAP URL Domain handler
#
# sock    socket back to the client
# suffix  the remainder of the url
#
proc SOAP::Domain::domain_handler {sock suffix} {
    variable debug
    variable soapspaces
    upvar \#0 Httpd$sock data
    
    set failed 0

    # check this is an XML post
    set failed [catch {set type $data(mime,content-type)} msg]
    if { $failed } {
        Httpd_ReturnData $sock text/xml \
                [fault SOAP-ENV:Client "Invalid SOAP request: not XML data"] \
                500
        return $failed
    }
    
    # make sure we were sent some XML
    set failed [catch {set query $data(query)} msg]
    if { $failed } {
        Httpd_ReturnData $sock text/xml \
                [fault SOAP-ENV:Client "Invalid SOAP request: no data sent"] \
                500
        return $failed
    }
    
    # Get the method name and parameters from the XML request. 
    set doc [dom::DOMImplementation parse $query]
    if { $debug } { set ::doc $doc }

    # methodNamespace should get set to the xmlns namespace in use.
    # However, parse strips the xmlns attributes.
    set methodName [xpath -name $doc "/Envelope/Body/*"]
    set methodNamespace [lindex [xmlnsSplit $methodName] 0]
    set methodName [lindex [xmlnsSplit $methodName] 1]
    if { [catch {xpath $doc "/Envelope/Body/${methodName}/*"} argValues] } {
        set argValues {}
    }
    if { ! $debug } {catch {dom::DOMImplementation destroy $doc}}

    # Check the procedure exists (so we can raise a fault with no details
    # as per SOAP-1.1 spec for fault in the header processing.
    set soapspace {}
    foreach ss $soapspaces {
        if { [catch {info args ::${ss}::${suffix}} ] == 0 } {
            set soapspace ::${ss}
            break
        }
    }
    if { $soapspace == {} } {
        Httpd_ReturnData $sock text/xml \
                [fault SOAP-ENV:Client \
                  "Invalid SOAP request: method \"$methodName\" not found" \
                ] 500
        return $failed
    }

    # Call the procedure and convert errors into SOAP Faults and the return
    # data into a SOAP return packet.
    set failed [catch "eval ${soapspace}::$suffix \$argValues" msg]
    if { $failed } {
        set detail [list "errorCode" $::errorCode "stackTrace" $::errorInfo]
        Httpd_ReturnData $sock text/xml \
                [fault SOAP-ENV:Client "$msg" $detail] 500
    } else {
        # FIX ME - $methodName should be the URI for this method.
        set reply [reply_simple [dom::DOMImplementation create] \
                $methodName "return" string $msg]
        
        # serialize and fix the DOM - doctype is not allowed (SOAP-1.1 spec)
        regsub {<!DOCTYPE[^>]*>\n} \
                [dom::DOMImplementation serialize $reply] {} xml
        Httpd_ReturnData $sock text/xml $xml 200
    }

    return $failed
}

# -------------------------------------------------------------------------

# Prepare a SOAP fault message
#
# faultcode   the SOAP faultcode e.g: SOAP-ENV:Client
# faultstring summary of the fault
# detail      list of {detailName detailInfo}
#
# returns the XML text of the SOAP Fault packet.
# 
proc SOAP::Domain::fault {faultcode faultstring {detail {}}} {
    set doc [dom::DOMImplementation create]
    set bod [reply_envelope $doc]
    set flt [dom::document createElement $bod "SOAP-ENV:Fault"]
    set fcd [dom::document createElement $flt "faultcode"]
    dom::document createTextNode $fcd $faultcode
    set fst [dom::document createElement $flt "faultstring"]
    dom::document createTextNode $fst $faultstring

    if { $detail != {} } {
        set dtl0 [dom::document createElement $flt "detail"]
        set dtl  [dom::document createElement $dtl0 "e:errorInfo"]
        dom::element setAttribute $dtl "xmlns:e" "urn:TclSOAP-ErrorInfo"
        
        foreach {detailName detailInfo} $detail {
            set err [dom::document createElement $dtl $detailName]
            dom::document createTextNode $err $detailInfo
        }
    }
    
    # serialize the DOM document and return the XML text
    regsub {<!DOCTYPE[^>]*>\n} [dom::DOMImplementation serialize $doc] {} r
    dom::DOMImplementation destroy $doc
    return $r
}

# -------------------------------------------------------------------------

# Generate the common portion of a SOAP replay packet
#
# doc   the document element of a DOM document
# returns the body node
proc SOAP::Domain::reply_envelope { doc } {
    set env [dom::document createElement $doc "SOAP-ENV:Envelope"]
    dom::element setAttribute $env \
            "xmlns:SOAP-ENV" "http://schemas.xmlsoap.org/soap/envelope/"
    dom::element setAttribute $env \
            "xmlns:xsi"      "http://www.w3.org/1999/XMLSchema-instance"
    dom::element setAttribute $env \
            "xmlns:xsd"      "http://www.w3.org/1999/XMLSchema"
    set bod [dom::document createElement $env "SOAP-ENV:Body"]
    return $bod
}

# -------------------------------------------------------------------------

# Generate a reply packet for a simple reply containing one result element
#
# doc         empty DOM document element
# uri         URI of the SOAP method
# methodName  the SOAP method name
# type        the stype of the reply (string, float etc)
# result      the reply data
#
# returns the DOM document root
#
proc SOAP::Domain::reply_simple { doc uri methodName type result } {
    set bod [reply_envelope $doc]
    set cmd [dom::document createElement $bod "ns:$methodName"]
    dom::element setAttribute $cmd "xmlns:ns" $uri
    dom::element setAttribute $cmd \
            "SOAP-ENV:encodingStyle" \
            "http://schemas.xmlsoap.org/soap/encoding/"
    set par [dom::document createElement $cmd "return"]
    dom::element setAttribute $par "xsi:type" "xsd:$type"
    dom::document createTextNode $par $result
    return $doc
}

# -------------------------------------------------------------------------

# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
