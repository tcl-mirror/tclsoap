# zsplatTest.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Sample SOAP methods for testing out the TclSOAP package.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id$

package require XMLRPC::TypedVariable

namespace eval urn:zsplat-Test {

    # ---------------------------------------------------------------------
    # Sample SOAP method returning a single string value that is the servers
    # current time in iso8601 point in time format.
    proc time {} {
	set r [XMLRPC::TypedVariable::create timeInstant \
		[clock format [clock seconds] -format {%Y%m%dT%H%M%S} \
		-gmt true]]
	return $r
    }

    # ---------------------------------------------------------------------
    # Sample SOAP method taking a single numeric parameter and returning
    # the square of the value.
    proc square {num} {
	if {[catch {expr $num + 0.0} num]} {
	    error "invalid arguments: \"num\" must be a number" {} CLIENT
	}
	return [expr $num * $num]
    }

    # ---------------------------------------------------------------------
    # Sample SOAP method taking a single numeric parameter and returning
    # the sum of two values.
    proc sum {lhs rhs} {
	if {[catch {expr $lhs + $rhs} r]} {
	    error "invalid arguments: both parameters must be numeric" \
		    {} CLIENT
	}
	return $r
    }

    # ---------------------------------------------------------------------
    # Method returning a struct type.
    proc platform {} {
	set result [array get ::tcl_platform]
	set result [XMLRPC::TypedVariable::create "struct" $result]
	return $result
    }

    # ---------------------------------------------------------------------
    # Sample SOAP method returning an array of structs. The structs are
    #  struct {
    #      string name;
    #      any    value;
    #  }
    proc printenv {} {
	set r {}
	foreach {name value} [array get ::env] {
	    lappend r [XMLRPC::TypedVariable::create "struct" \
		    [list "name" $name "value" $value]]
	}
	set result [XMLRPC::TypedVariable::create "array" $r]
	return $result
    }
    
    # ---------------------------------------------------------------------
    # just return an array of strings.
    proc printenv_names {} {
	set result [array names ::env]
	set result [XMLRPC::TypedVariable::create "array(string)" $result]
	return $result
    }

    # ---------------------------------------------------------------------
    # Sample SOAP method returning an error
    proc mistake {} {
	error "It's a mistake!" {} SERVER
    }
}

#
# Local variables:
# mode: tcl
# End:
