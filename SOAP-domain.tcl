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

package provide SOAP::Domain 0.1

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

package require SOAP::xpath

namespace eval SOAP::Domain {
    variable version 0.1
    variable rcs_id {$Id$}

    namespace export fault reply_envelope reply_simple
}

# -------------------------------------------------------------------------

# Register this package with tclhttpd.
#
#  virtual  url prefix to use (ie: /soap)
#  args     any other options
#
proc SOAP::Domain::register {virtual args} {
    Url_PrefixInstall $virtual [list SOAP::Domain::domain_handler] $args
}

# -------------------------------------------------------------------------

# SOAP URL Domain handler
#
# sock    socket back to the client
# suffix  the remainder of the url
#
proc SOAP::Domain::domain_handler {sock suffix} {
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
    
    # now branch on $suffix (eg: /base64)
    set failed [catch "eval [namespace current]::$suffix [list \$query]" msg]
    if { $failed } {
        Httpd_ReturnData $sock text/html \
                [fault SOAP-ENV:Client \
                     "Invalid method name: $suffix not found $msg"] \
                     500
    } else {
        set code [lindex $msg 0]
        set xml  [lindex $msg 1]
        Httpd_ReturnData $sock text/html $xml $code
    }

    return $failed
}

# -------------------------------------------------------------------------

# Prepare a SOAP fault message
#
# faultcode   the SOAP faultcode e.g: SOAP-ENV:Client
# faultstring summary of the fault
# detail      list of detail {}
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

    # FIX ME
    #set dtl [dom::document createElement $flt "detail"]

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
# Examples of SOAP methods
# -------------------------------------------------------------------------
#
# All of these procedures are called by the domain_handler procedure with
# the following parameters:
#   query   XML text of the SOAP query
#   args    anything else
# They all return the XML text of the reply
#
# -------------------------------------------------------------------------

# FIX ME
#
# All these could do with more validation of namespace specs.
#
# Could probably use a proc to convert the SOAP parameters from the XML 
# into an array as [array set params { param1 value param2 value ... }]
# would make the method code simpler.


# base64 - convert the input string parameter to a base64 encoded string
#
# parameters: 
#  message as string
# returns:
#
proc SOAP::Domain::/base64 {query args} {
    # parse into a DOM document
    set doc [dom::DOMImplementation parse $query]

    set failed [catch {SOAP::xpath::xpath $doc "Envelope/Body/base64"} text]
    if { $failed } {
        set reply [fault SOAP-ENV:Client "Incorrect method name: should be \"base64\""]
    }

    if { ! $failed } {
        set failed [catch {SOAP::xpath::xpath $doc "Envelope/Body/base64/*"} text]
        if { $failed } {
            set reply [fault SOAP-ENV:Client \
                "Missing parameter: should be \"base64 string\""]
        } else {
            set reply [reply_simple [dom::DOMImplementation create] \
                    zsplat-Base64 base64 string [base64::encode $text]]
        }
    }

    # serialize and fix the DOM.
    regsub {<!DOCTYPE[^>]*>\n} [dom::DOMImplementation serialize $reply] {} r

    # clean up the DOM structures
    dom::DOMImplementation destroy $doc
    dom::DOMImplementation destroy $reply

    if { $failed } { set code 500 } else { set code 200 }
    return [list $code $r]
}

# -------------------------------------------------------------------------

# time - return the servers idea of the time
#
# parameters:
#   none
# returns:
#   time as string
#
proc SOAP::Domain::/time {query args} {
    set doc [dom::DOMImplementation parse $query]
    
    set reply [reply_simple [dom::DOMImplementation create] \
            zsplat-Time time string [clock format [clock seconds]]]

    # serialize and fix the DOM.
    regsub {<!DOCTYPE[^>]*>\n} [dom::DOMImplementation serialize $reply] {} r

    # clean up the DOM structures
    dom::DOMImplementation destroy $doc
    dom::DOMImplementation destroy $reply

    return [list 200 $r]
}

# rcsid - return the RCS version string for this package
# parameters - none
# returns: a string
#
proc SOAP::Domain::/rcsid {query args} {
    variable rcs_id
    set reply [reply_simple [dom::DOMImplementation create] \
            zsplat-rcsid rcsid string $rcs_id]

    # serialize and fix the DOM.
    regsub {<!DOCTYPE[^>]*>\n} [dom::DOMImplementation serialize $reply] {} r

    # clean up the DOM structures
    dom::DOMImplementation destroy $reply

    return [list 200 $r]
}

proc SOAP::Domain::/WiRECameras/get_Count {query args} {
    package require Renicam
    set ncameras [renicam count]
    set reply [reply_simple [dom::DOMImplementation create] \
           zsplat-WiRECameras get_Count integer $ncameras]

    # serialize and fix the DOM.
    regsub {<!DOCTYPE[^>]*>\n} [dom::DOMImplementation serialize $reply] {} r

    # clean up the DOM structures
    dom::DOMImplementation destroy $reply

    return [list 200 $r]
}

# -------------------------------------------------------------------------

# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
