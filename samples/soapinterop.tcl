# Client implementation of the SOAP Interoperability lab Round 1 Test Suite.

package require SOAP
package require XMLRPC
package require rpcvar

namespace eval soapinterop {
    variable uri    "http://soapinterop.org/"
    variable action "urn:soapinterop"

    # ---------------------------------------------------------------------
    # types
    # ---------------------------------------------------------------------

    rpcvar::typedef -namespace http://soapinterop.org/xsd { \
	    varString string \
	    varInt    int \
	    varFloat  float} SOAPStruct

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
	    string()() ArrayOfString2D
    
    rpcvar::typedef -namespace http://soapinterop.org/xsd { \
	    varString string \
	    varInt    int \
	    varFloat  float \
	    varArray  string() } SOAPArrayStruct

    # ----------------------------------------------------------------------

    proc create {proxy} {
        variable uri
        variable action
        
        SOAP::create echoString  -proxy $proxy -uri $uri -action $action \
                -params {inputString string}
        SOAP::create echoInteger -proxy $proxy -uri $uri -action $action \
                -params {inputInteger int}
        SOAP::create echoFloat -proxy $proxy -uri $uri -action $action \
                -params {inputFloat float}
        SOAP::create echoStruct -proxy $proxy -uri $uri -action $action \
                -params {inputStruct SOAPStruct}
        
        SOAP::create echoStringArray -proxy $proxy -uri $uri -action $action \
                -params {inputStringArray string()}
        SOAP::create echoIntegerArray -proxy $proxy -uri $uri -action $action \
                -params {inputIntegerArray int()}
        SOAP::create echoFloatArray -proxy $proxy -uri $uri -action $action \
                -params {inputFloatArray float()}
        SOAP::create echoStructArray -proxy $proxy -uri $uri -action $action \
                -params {inputStructArray SOAPStruct()}

        SOAP::create echoBase64 -proxy $proxy -uri $uri -action $action \
                -params {inputBase64 base64}
        SOAP::create echoDate -proxy $proxy -uri $uri -action $action \
                -params {inputDate timeInstant}
        SOAP::create echoVoid -proxy $proxy -uri $uri -action $action \
                -params {}

	# Proposal B Methods
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

    proc test_local {} {
        create http://localhost/cgi-bin/rpc
    }

    proc test_4s4c {} {
        create http://soap.4s4c.com/ilab/soap.asp
    }

    test_4s4c
}

proc soapinterop::validate {{proxy {}}} {
    if {$proxy != {}} {
	create $proxy
    }

    catch {validate.echoVoid} msg        ; puts "$msg"
    catch {validate.echoDate} msg        ; puts "$msg"
    catch {validate.echoBase64} msg      ; puts "$msg"
    catch {validate.echoInteger} msg     ; puts "$msg"
    catch {validate.echoFloat} msg       ; puts "$msg"
    catch {validate.echoString} msg      ; puts "$msg"
    catch {validate.echoIntegerArray} msg; puts "$msg"
    catch {validate.echoFloatArray} msg  ; puts "$msg"
    catch {validate.echoStringArray} msg ; puts "$msg"
    catch {validate.echoStruct} msg      ; puts "$msg"
    catch {validate.echoStructArray} msg ; puts "$msg"
}

proc soapinterop::rand_float {} {
    set r [expr rand() * 200 - 100]
    set p [string first . $r]
    incr p 4
    return [string range $r 0 $p]
}

proc soapinterop::rand_int {} {
    return [expr int(rand() * 200 - 100) ]
}

proc soapinterop::validate.echoVoid {} {
    set r [echoVoid]
    if {$r != {}} { error "echoVoid failed" }
    return "echoVoid"
}

proc soapinterop::validate.echoDate {} {
    set d [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
    set r [echoDate $d]
    if {! [string match "$d*" $r]} {
	error "echoDate failed: $d != $r"
    }
    return "echoDate"
}

proc soapinterop::validate.echoBase64 {} {
    package require base64
    set check [array get ::tcl_platform]
    set q [join [base64::encode $check] {}]
    set result [echoBase64 $q]
    set r [base64::decode $result]
    if {![string match $check $r]} {
	error "echoBase64 failed: strings do not match"
    }
    return "echoBase64"
}

proc soapinterop::validate.echoInteger {} {
    set i [rand_int]
    set r [echoInteger $i]
    if {$i != $r} { error "echoInteger failed: $i != $r" }
    return "echoInteger"
}

# Tend to loose some decimal places. Check to ?? dp ??
proc soapinterop::validate.echoFloat {} {
    set f [rand_float]
    set r [echoFloat $f]
    if {[expr $f != $r]} {
	error "echoFloat failed: $f != $r" 
    }
    return "echoFloat"
}

proc soapinterop::validate.echoString {} {
    set s [array get ::tcl_platform]
    set r [echoString $s]
    if {! [string match $s $r]} {
	error "echoString failed simple string test: $s != $r"
    }
    return "echoString"
}

proc soapinterop::validate.echoIntegerArray {} {
    set max [expr int(rand() * 19 + 2)]
    for {set n 0} {$n < $max} {incr n} {
	lappend q [rand_int]
    }
    set r [echoIntegerArray $q]
    if {[llength $r] != [llength $q]} {
	error "echoIntegerArray failed: lists are different: $r != $q"
    }
    for {set n 0} {$n < $max} {incr n} {
	if {[lindex $q $n] != [lindex $r $n]} {
	    error "echoIntegerArray failed: element $n is different: $r != $q"
	}
    }
    return "echoIntegerArray"
}

proc soapinterop::validate.echoFloatArray {} {
    set max [expr int(rand() * 19 + 2)]
    for {set n 0} {$n < $max} {incr n} {
	lappend q [rand_float]
    }
    set r [echoFloatArray $q]
    if {[llength $r] != [llength $q]} {
	error "echoFloatArray failed: lists are different: $r != $q"
    }
    for {set n 0} {$n < $max} {incr n} {
	if {[expr [lindex $q $n] != [lindex $r $n]]} {
	    error "echoFloatArray failed: element $n is different: $r != $q"
	}
    }
    return "echoFloatArray"
}

proc soapinterop::validate.echoStringArray {} {
    set q [array get ::tcl_platform]
    set r [echoStringArray $q]
    if {[llength $r] != [llength $q]} {
	error "echoStringArray failed: lists are different: $r != $q"
    }
    set max [llength $q]
    for {set n 0} {$n < $max} {incr n} {
	if {! [string match [lindex $q $n] [lindex $r $n]]} {
	    error "echoStringArray failed: element $n is different: $r != $q"
	}
    }
    return "echoStringArray"
}

proc soapinterop::validateSOAPStruct {first second} {
    array set f $first
    array set s $second
    foreach key [array names f] {
	set type [rpcvar::rpctype $f($key)]
	switch -- $type {
	    double  { set r [expr $f($key) == $s($key)] }
	    float   { set r [expr $f($key) == $s($key)] }
	    int     { set r [expr $f($key) == $s($key)] }
	    default { set r [string match $f($key) $s($key)] }
	}
	if {! $r} {
	    error "echoStruct failed: mismatching \"$key\" element\
		    $f($key) != $s($key)"
	}
    }
}

proc soapinterop::validate.echoStruct {} {
    set q [list \
	    varInt [rand_int] \
	    varFloat [rand_float] \
	    varString "$::tcl_platform(platform)$::tcl_platform(user)"]
    set r [echoStruct $q]
    validateSOAPStruct $q $r
    return "echoStruct"
}

proc soapinterop::validate.echoStructArray {} {

    set max [expr int(rand() * 19 + 2)]
    for {set n 0} {$n < $max} {incr n} {
	lappend q [list \
		varInt [rand_int] \
		varFloat [rand_float] \
		varString [lindex [info commands] $n]]
    }
    
    set r [echoStructArray $q]
    for {set n 0} {$n < $max} {incr n} {
	validateSOAPStruct [lindex $q $n] [lindex $r $n]
    }
    return "echoStructArray"
}

# -------------------------------------------------------------------------

# Proposal B

# Returns the struct parts.
proc soapinterop::validate.echoStructAsSimpleTypes {} {
    array set q [list \
	    varString "" \
	    varInt [rand_int] \
	    varFloat [rand_float]]
    set r [echoStructAsSimpleTypes [array get q]]
    return $r
}    


# -------------------------------------------------------------------------

#
# Local variables:
# mode: tcl
# End:
