# XMLRPC-domain.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# XML-RPC Domain Service module for the tclhttpd web server.
# See samples/xmlrpc-methods-server.tcl for a usage example.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

# XML-RPC Valid Types:
#  (from the specification document http://www.xmlrpc.com/)
#
#  <i4> or <int>       four-byte signed integer -12
#  <boolean>           0 (false) or 1 (true) 1
#  <string>            ASCII string hello world 
#  <double>            double-precision signed floating point number -12.214 
#  <dateTime.iso8601>  date/time 19980717T14:08:55 
#  <base64>            base64-encoded binary eW91IGNhbid0IHJlYWQgdGhpcyE= 
#
# Struct:
#   <struct>
#       <member>
#          <name>_cx</name>
#          <value><int>100</int></value>
#       </member>
#       <members...
#   </struct>
# Array: a bit like structs but unnamed members.
#   <array>
#      <data>
#         <value><i4>1</i4>
#         <value><string>Hello</string></value>
#         ...
#      </data>
#   </array>

package provide XMLRPC::Domain 1.0

if { [catch {package require dom 2.0}] } {
    if { [catch {package require dom 1.6}] } {
        error "require dom package greater than 1.6"
    }
}

package require XMLRPC::TypedVariable 1.0
package require SOAP::xpath

namespace eval XMLRPC::Domain {
    variable version 1.0   ;# package version number
    variable debug 1       ;# debugging flag
    variable rcs_id {$Id: XMLRPC-domain.tcl,v 1.4 2001/06/19 00:40:26 patthoyts Exp $}

    namespace export fault
}

# -------------------------------------------------------------------------

# Description:
#   Register this package with tclhttpd.
#     e.g.: register -prefix /rpc ?-namespace ::RPC? ?-interp slave?
# Parameters:
#   -prefix    - the URL prefix for the SOAP methods to be implemented under
#   -interp    - the Tcl slave interpreter to use ( {} for the current interp)
#   -namespace - the Tcl namespace look for the implementations under
#                (default is global)
#   -uri       - the XML namespace for these methods. Defaults to the Tcl 
#                interpreter and namespace name.
# Result:
#   Registers the relevant handlers with the tclhttpd package and returns
#   the URL prefix selected.
#
proc XMLRPC::Domain::register {args} {

    if { [llength $args] < 1 } {
        error "invalid # args: should be \"register ?option value  ...?\""
    }

    # set the default options. These work out to be the current interpreter,
    # toplevel namespace and under /soap URL
    array set opts [list \
            -prefix /xmlrpc \
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
    # links to out implementation in this interpreter in the SOAP::Domain
    # namespace.
    interp alias $opts(-interp) $opts(-namespace)::URLhandler \
            {} [namespace current]::domain_handler $optname

    # Register with tclhttpd now.
    Url_PrefixInstall $opts(-prefix) \
            "interp eval [list $opts(-interp)] $opts(-namespace)::URLhandler"

    # log the uri/domain registration
    array set [namespace current]::opts$opts(-prefix) [array get opts]

    return $opts(-prefix)
}

# -------------------------------------------------------------------------

# Description:
#   XMLRPC URL Domain handler
#   Called from the namespace or interpreter domain_handler to perform the
#   work.
# Parameters:
#   optsname - qualified name of the options array set up during registration.
#   sock     - socket back to the client
#   suffix   - the remainder of the url once the prefix was stripped.
# Result:
#   Processes the request and calles the implementing procedure if it can
#   be found. If an error is produced a fault reply is generated otherwise
#   a properly structured XML-RPC reply is built and returned to the client.
#   Returns 1 for a failed reply or 0 if everything went smoothly.
#
proc XMLRPC::Domain::domain_handler {optsname sock args} {
    variable debug
    upvar \#0 Httpd$sock data
    
    # if suffix is {} then it fails to make it through the various evals.
    set suffix [lindex $args 0]
    
    # Import the SOAP::xpath stuff for now.
    namespace import -force ::SOAP::xpath::*

    # check this is an XML post
    set failed [catch {set type $data(mime,content-type)} msg]
    if { $failed } {
        Httpd_ReturnData $sock text/xml \
                [fault 500 "Invalid RPC request: not XML data"] 200
        return $failed
    }
    
    # make sure we were sent some XML
    set failed [catch {set query $data(query)} msg]
    if { $failed } {
        Httpd_ReturnData $sock text/xml \
                [fault 500 "Invalid RPC request: no data sent"] 200
        return $failed
    }

    # Check that we have a properly registered domain
    if { ! [info exists $optsname] } {
        Httpd_ReturnData $sock text/xml \
                [fault 500 \
		   "Internal server error: domain improperly registered"] \
		200
        return 1
    }        

    # Get the method name and parameters from the XML request. 
    set doc [dom::DOMImplementation parse $query]
    if { $debug } { set ::doc $doc }

    # This could probably be better done using XPath methods...
    #
    #set methodName [xpath $doc "/methodCall/methodName"]
    #if { [catch {xpath $doc "/Envelope/Body/${methodName}/*"} argValues] } {
    #    set argValues {}
    #}
    set argValues [SOAP::Parse::parse $query]
    set methodName [lindex $argValues 0]
    set argValues [lrange $argValues 1 end]

    if { ! $debug } {catch {dom::DOMImplementation destroy $doc}}

    # The implementation of this method will be in xmlinterp and the procname
    # is going to be namespace + suffix.
    set xmlns {}
    set xmlinterp [lindex [array get $optsname -interp] 1]
    append xmlns [lindex [array get $optsname -namespace] 1] {::} $suffix

    # Check that this method has an implementation. If not then we return an
    # error with no <detail> element (as per SOAP 1.1 specification) 
    # indicating an error in header processing.
    if { [catch {interp eval $xmlinterp namespace origin $xmlns} xmlns] } {
        Httpd_ReturnData $sock text/xml \
                [fault 500 \
                  "Invalid RPC request: method \"$methodName\" not found"
                ] 200
        return 1
    }

    # The URI for this method will be
    set xmluri [lindex [array get $optsname -uri] 1]

    # Call the procedure and convert errors into Faults and the return
    # data into a response packet.
    set failed [catch {interp eval $xmlinterp [list $xmlns] $argValues} msg]
    if { $failed } {
        set detail [list "errorCode" $::errorCode "stackTrace" $::errorInfo]
        Httpd_ReturnData $sock text/xml \
                [fault 500 "$msg" $detail] 200
    } else {

        set reply [reply_simple [dom::DOMImplementation create] \
                $xmluri "return" string $msg]
        
        # serialize and fix the DOM - doctype is not allowed (SOAP-1.1 spec)
        regsub "<!DOCTYPE\[^>\]*>\n" \
                [dom::DOMImplementation serialize $reply] {} xml
        catch {dom::DOMImplementation destroy $reply}
        Httpd_ReturnData $sock text/xml $xml 200
    }

    return $failed
}

# -------------------------------------------------------------------------

# Description:
#   Prepare an XML-RPC fault response
# Parameters:
#   faultcode   the XML-RPC fault code (numeric)
#   faultstring summary of the fault
#   detail      list of {detailName detailInfo}
# Result:
#   Returns the XML text of the SOAP Fault packet.
#
proc XMLRPC::Domain::fault { faultcode faultstring {detail {}} } {
    set xml [join [list \
	    "<?xml version=\"1.0\" ?>" \
	    "<methodResponse>" \
	    "  <fault>" \
	    "    <value>" \
	    "      <struct>" \
	    "        <member>" \
	    "           <name>faultCode</name>"\
	    "           <value><int>${faultcode}</int></value>" \
	    "        </member>" \
	    "        <member>" \
	    "           <name>faultString</name>"\
	    "           <value><string>${faultstring}</string></value>" \
	    "        </member>" \
	    "      </struct> "\
	    "    </value>" \
	    "  </fault>" \
	    "</methodResponse>"] "\n"]
    return $xml
}

# -------------------------------------------------------------------------

# Description:
#   Generate a reply packet for a simple reply containing one result element
# Parameters:
#   doc         empty DOM document element
#   uri         URI of the SOAP method
#   methodName  the SOAP method name
#   type        the stype of the reply (string, float etc)
#   result      the reply data
# Result:
#   Returns the DOM document root of the generated reply packet
#
proc XMLRPC::Domain::reply_simple { doc uri methodName type result } {
    set d_root [dom::document createElement $doc "methodResponse"]
    set d_params [dom::document createElement $d_root "params"]
    set d_param [dom::document createElement $d_params "param"]
    set d_value [dom::document createElement $d_param "value"]
    insert_value $d_value $result
    return $doc
}

# -------------------------------------------------------------------------

proc XMLRPC::Domain::insert_value {node value} {
    set type [XMLRPC::TypedVariable::get_type $value]
    set value [XMLRPC::TypedVariable::get_value $value]

    if { $type == "array" } {
        set d_array [dom::document createElement $node "array"]
        set d_data [dom::document createElement $d_array "data"]
        foreach elt $value {
            set d_elt [dom::document createElement $d_data "value"]
            insert_value $d_elt $elt
        }
    } elseif { $type == "struct" } {
        # Arrays have been expanded for us with array get ...
        set d_struct [dom::document createElement $node "struct"]
        foreach {eltname eltvalue} $value {
            set d_mmbr [dom::document createElement $d_struct "member"]
            set d_name [dom::document createElement $d_mmbr "name"]
            dom::document createTextNode $d_name $eltname
            set d_value [dom::document createElement $d_mmbr "value"]
            insert_value $d_value $eltvalue
        }
    } else {
        set d_type [dom::document createElement $node $type]
        dom::document createTextNode $d_type $value
    }
}

# -------------------------------------------------------------------------

# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
