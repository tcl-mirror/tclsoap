# SOAP-domain.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
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

package provide SOAP::Domain 1.3

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

package require SOAP::xpath
package require SOAP::Utils
package require rpcvar

namespace eval SOAP::Domain {
    variable version 1.3  ;# package version number
    variable debug 0      ;# flag to toggle debug output
    variable rcs_id {$Id: SOAP-domain.tcl,v 1.9 2001/08/03 21:48:50 patthoyts Exp $}

    namespace export fault reply_envelope reply_simple
    catch {namespace import -force [namespace parent]::Utils::*}
    catch {namespace import -force [uplevel {namespace current}]::rpcvar::*}
}

# -------------------------------------------------------------------------

# Register this package with tclhttpd.
#
# eg: register -prefix /soap ?-namespace ::zsplat? ?-interp slave?
#
# -prefix is the URL prefix for the SOAP methods to be implemented under
# -interp is the Tcl slave interpreter to use ( {} for the current interp)
# -namespace is the Tcl namespace look for the implementations under
#            (default is global)
# -uri    the XML namespace for these methods. Defaults to the Tcl interpreter
#         and namespace name.
#
proc SOAP::Domain::register {args} {

    if { [llength $args] < 1 } {
        error "invalid # args: should be \"register ?option value  ...?\""
    }

    # set the default options. These work out to be the current interpreter,
    # toplevel namespace and under /soap URL
    array set opts [list \
            -prefix /soap \
            -namespace {::} \
            -interp {} \
            -uri {^} ]

    # process the arguments
    foreach {opt value} $args {
        switch -glob -- $opt {
            -pre* {set opts(-prefix) $value}
            -nam* {set opts(-namespace) ::$value}
            -int* {set opts(-interp) $value}
            -uri  {set opts(-uri) $value}
            default {
                error "unrecognised option \"$opt\": must be \"-prefix\",\
                        \"-namespace\", \"-interp\" or \"-uri\""
            }
        }
    }

    # Construct a URI if not supplied (as indicated by the funny character)
    # gives interpname hyphen namespace path (with more hyphens)
    if { $opts(-uri) == {^} } {
        set opts(-uri) 
        regsub -all -- {::+} "$opts(-interp)::$opts(-namespace)" {-} r
        set opts(-uri) [string trim $r -]
    }

    # Generate the fully qualified name of our options array variable.
    set optname [namespace current]::opts$opts(-prefix)

    # check we didn't already have this registered.
    if { [info exists $optname] } {
        error "URL prefix \"$opts(-prefix)\" already registered"
    }

    # set up the URL domain handler procedure.
    # As interp eval {} evaluates in the current interpreter we can define
    # both a slave interpreter _and_ a specific namespace if we need.

    # If required create a slave interpreter.
    if { $opts(-interp) != {} } {
        catch {interp create -- $opts(-interp)}
    }
    
    # Now create a command in the slave interpreter's target namespace that
    # links to our implementation in this interpreter in the SOAP::Domain
    # namespace.
    interp alias $opts(-interp) $opts(-namespace)::URLhandler \
            {} [namespace current]::domain_handler $optname

    # Register the URL handler with tclhttpd now.
    Url_PrefixInstall $opts(-prefix) \
            "interp eval [list $opts(-interp)] $opts(-namespace)::URLhandler"

    # log the uri/domain registration
    array set [namespace current]::opts$opts(-prefix) [array get opts]

    return $opts(-prefix)
}

# -------------------------------------------------------------------------

# SOAP URL Domain handler
#
# Called from the namespace or interpreter domain_handler to perform the
# work.
# optsname the qualified name of the options array set up during registration.
# sock     socket back to the client
# suffix   the remainder of the url once the prefix was stripped.
#
proc SOAP::Domain::domain_handler {optsname sock args} {
    variable debug
    upvar \#0 Httpd$sock data
    
    # if suffix is {} then it fails to make it through the various evals.
    set suffix [lindex $args 0]
    
    # Import the SOAP::xpath stuff for now.
    namespace import -force [namespace parent]::xpath::*

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

    # Check that we have a properly registered domain
    if { ! [info exists $optsname] } {
        Httpd_ReturnData $sock text/xml \
                [fault SOAP-ENV:Server "Internal server error: domain improperly registered"] \
                500
        return 1
    }        

    # Get the method name and parameters from the XML request. 
    set doc [dom::DOMImplementation parse $query]
    if { $debug } { set ::doc $doc }

    # methodNamespace should get set to the xmlns namespace in use.
    # However, dom::DOMImplementation parse strips the xmlns attributes.
    # FIX ME
    #
    # - matches the code in SOAP::CGI ----------------------------------
    set methodNode [selectNode $doc "/Envelope/Body/*"]
    set methodName [dom::node cget $methodNode -nodeName]
    set methodNamespace [array get [dom::node cget $methodNode -attributes]]
    set argNodes [selectNode $doc "/Envelope/Body/*/*"]
    set argValues {}
    foreach node $argNodes {
        lappend argValues [decomposeSoap $node]
    }
    catch {dom::DOMImplementation destroy $doc}
    # ------------------------------------------------------------------

    # The implementation of this method will be in xmlinterp and the procname
    # is going to be namespace + suffix.
    # NB: suffix is prefixed by '/'. We will search for an implementation by
    # looking for 'registered namespace'::/methodname followed by
    # 'registered namespace'::methodname
    # We also determine which interpreter is used here.
    set xmlns {} ; set xmlns2 {}
    set xmlinterp [lindex [array get $optsname -interp] 1]
    append xmlns  [lindex [array get $optsname -namespace] 1] {::} $suffix
    append xmlns2 [lindex [array get $optsname -namespace] 1] {::} $methodName
    #            [string range $suffix 1 end]

    # Check that this method has an implementation. If not then we return an
    # error with no <detail> element (as per SOAP 1.1 specification) 
    # indicating an error in header processing.
    if { [catch {interp eval $xmlinterp namespace origin $xmlns} xmlns] } {
        if {[catch {interp eval $xmlinterp namespace origin $xmlns2} xmlns]} {
            Httpd_ReturnData $sock text/xml \
                    [fault SOAP-ENV:Client \
                      "Invalid SOAP request: method \"$methodName\" not found"
                    ] 500
            return 1
        }
    }

    # The URI for this method will be
    set xmluri [lindex [array get $optsname -uri] 1]

    # Call the procedure and convert errors into SOAP Faults and the return
    # data into a SOAP return packet.
    set failed [catch {interp eval $xmlinterp [list $xmlns] $argValues} msg]
    if { $failed } {
        set detail [list "errorCode" $::errorCode "stackTrace" $::errorInfo]
        Httpd_ReturnData $sock text/xml \
                [fault SOAP-ENV:Client "$msg" $detail] 500
    } else {

        set reply [reply_simple \
                [dom::DOMImplementation create] \
                $xmluri "${methodName}Response" $msg]
        
        # serialize and fix the DOM - doctype is not allowed (SOAP-1.1 spec)
        regsub "<!DOCTYPE\[^>\]*>\n" \
                [dom::DOMImplementation serialize $reply] {} xml
        catch {dom::DOMImplementation destroy $reply}
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
    regsub "<!DOCTYPE\[^>\]*>\n" [dom::DOMImplementation serialize $doc] {} r
    dom::DOMImplementation destroy $doc
    return $r
}

# -------------------------------------------------------------------------

# Generate the common portion of a SOAP replay packet
#
# doc   the document element of a DOM document
#
# returns the body node
#
proc SOAP::Domain::reply_envelope { doc } {
    set env [dom::document createElement $doc "SOAP-ENV:Envelope"]
    dom::element setAttribute $env \
            "xmlns:SOAP-ENV" "http://schemas.xmlsoap.org/soap/envelope/"
    dom::element setAttribute $env \
            "xmlns:xsi"      "http://www.w3.org/1999/XMLSchema-instance"
    dom::element setAttribute $env \
            "xmlns:xsd"      "http://www.w3.org/1999/XMLSchema"
    dom::element setAttribute $env \
            "xmlns:SOAP-ENC" "http://schemas.xmlsoap.org/soap/encoding/"
    set bod [dom::document createElement $env "SOAP-ENV:Body"]
    return $bod
}

# -------------------------------------------------------------------------

# Description:
#   Generate a reply packet for a simple reply containing one result element
# Parameters:
#   doc         empty DOM document element
#   uri         URI of the SOAP method
#   methodName  the SOAP method name
#   result      the reply data
# Returns:
#   returns the DOM document root
#
proc SOAP::Domain::reply_simple { doc uri methodName result } {
    set bod [reply_envelope $doc]
    set cmd [dom::document createElement $bod "ns:$methodName"]
    dom::element setAttribute $cmd "xmlns:ns" $uri
    dom::element setAttribute $cmd \
            "SOAP-ENV:encodingStyle" \
            "http://schemas.xmlsoap.org/soap/encoding/"

    # insert the results into the DOM tree (unless it's a void result)
    if {$result != {}} {
        set retnode [dom::document createElement $cmd "return"]
        SOAP::insert_value $retnode $result
    }

    return $doc
}

# -------------------------------------------------------------------------

# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
