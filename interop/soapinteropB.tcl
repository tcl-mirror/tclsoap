# soapinteropB.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# SOAP Interoperability Lab "Round 2" Proposal B Client Tests
# 
# See http://www.whitemesa.com/interop.htm for details.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id$

package require -exact soapinterop::base 1.0
package provide soapinterop::B 1.0

namespace eval soapinterop {

    rpcvar::typedef -namespace http://soapinterop.org/xsd { \
	    varString string \
	    varInt    int \
	    varFloat  float \
	    varStruct SOAPStruct } SOAPStructStruct

    # FIX ME
    rpcvar::typedef -namespace http://soapinterop.org/xsd \
	    string() Arrayofstring

    # FIX ME
    rpcvar::typedef -namespace http://soapinterop.org/xsd \
	    string(,) ArrayOfString2D
    
    rpcvar::typedef -namespace http://soapinterop.org/xsd { \
	    varString string \
	    varInt    int \
	    varFloat  float \
	    varArray  string() } SOAPArrayStruct
}

# -------------------------------------------------------------------------

# Proposal B Methods
proc soapinterop::create:proposalB {proxy} {
    variable action
    variable uri

    set action http://soapinterop.org/

    SOAP::create echoStructAsSimpleTypes -proxy $proxy -uri $uri \
	-action $action -params {inputStruct SOAPStruct}
    SOAP::create echoSimpleTypesAsStruct -proxy $proxy -uri $uri \
	-action $action \
	-params {inputString string inputInteger int inputFloat float}
    SOAP::create echo2DStringArray -proxy $proxy -uri $uri \
	-action $action -params {input2DStringArray ArrayOfString2D}
    SOAP::create echoNestedStruct -proxy $proxy -uri $uri -action $action \
	-params {inputStruct SOAPStructStruct}
    SOAP::create echoNestedArray -proxy $proxy -uri $uri -action $action \
	-params {inputStruct SOAPArrayStruct}

}

# -------------------------------------------------------------------------

proc soapinterop::round2:proposalB {proxy} {
    create:proposalB $proxt
    catch {validate.echoStructAsSimpleTypes} msg ; puts "$msg"
    catch {validate.echoSimpleTypesAsStruct} msg ; puts "$msg"
}

# -------------------------------------------------------------------------

# Description:
#  Returns the struct parts individually.
#  We check that each member value was returned (we cannot assume a
#  particular order.
#
proc soapinterop::validate.echoStructAsSimpleTypes {} {
    array set q [list varString [rand_string] \
                     varInt    [rand_int] \
                     varFloat  [rand_float]]
    set r [echoStructAsSimpleTypes [array get q]]

    foreach {n e} [array get q] {
        if {[lsearch -exact $r $e] == -1} {
            error "failed: member $n not found in \"$r\""
        }
    }
    return "echoStructAsSimpleTypes"
}    

# -------------------------------------------------------------------------

proc soapinterop::validate.echoSimpleTypesAsStruct {} {
    set s [rand_string]
    set i [rand_int]
    set f [rand_float]
    array set r [echoSimpleTypesAsStruct $s $i $f]
    
    if {![string match $s $r(varString)]} {
        error "failed: varString \"$s\" != \"$r(varString)\""
    }
    if {$i != $r(varInt)} {
        error "failed: varInt $i != $r(varInt)"
    }
    if {$f != $r(varFloat)} {
        error "failed: varFloat $f != $r(varFloat)"
    }

}

# -------------------------------------------------------------------------

#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
