# validator.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Implement the http://vaalidator.soapware.org/ interoperability suite.
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

# -------------------------------------------------------------------------

# Optional feature used by the validator at http://validator.soapware.org/
# Helps them to work out what SOAP toolkit is providing the service.
#
proc whichToolkit {} {
    if {[catch {package require SOAP} soapVersion]} {
	set soapVersion {unknown}
    }
    set r(toolkitDocsUrl)         "http://tclsoap.sourceforge.net/"
    set r(toolkitName)            "TclSOAP"
    set r(toolkitVersion)         $soapVersion
    set r(toolkitOperatingSystem) "System Independent"
    return [XMLRPC::TypedVariable::create "struct" [array get r]]
}

# -------------------------------------------------------------------------

# validator1.countTheEntities (s) returns struct
#
# This handler takes a single parameter named s, a string, that
# contains any number of predefined entities, namely <, >, &, ' and ".
#
# Your handler must return a struct that contains five fields, all
# numbers: ctLeftAngleBrackets, ctRightAngleBrackets, ctAmpersands,
# ctApostrophes, ctQuotes.
#
# To validate, the numbers must be correct.
#
proc countTheEntities {s} {
    array set a {< 0 > 0 & 0 ' 0 \" 0}
    foreach c [split $s {}] {
	if {[catch {incr a($c)}]} {
	    set a($c) 1
	}
    }
    set r(ctLeftAngleBrackets) $a(<)
    set r(ctRightAngleBrackets) $a(>)
    set r(ctAmpersands) $a(&)
    set r(ctApostrophes) $a(\')
    set r(ctQuotes) $a(\")
    return [XMLRPC::TypedVariable::create "struct" [array get r]]
}

# -------------------------------------------------------------------------

# validator1.easyStructTest (stooges) returns number
#
# This handler takes a single parameter named stooges, a struct,
# containing at least three elements named moe, larry and curly, all
# ints. Your handler must add the three numbers and return the result.    
#
proc easyStructTest {stooges} {
    array set stooge $stooges
    set r [expr $stooge(larry) + $stooge(curly) + $stooge(moe)]
    return $r
}

# -------------------------------------------------------------------------

# validator1.echoStructTest (myStruct) returns struct
#
# This handler takes a single parameter named myStruct, a struct. Your
# handler must return the struct.
#
# This is a struct of structs (actually an array but with different names
# for each item).
#
proc echoStructTest {myStruct} {
    set r {}
    foreach {name value} $myStruct {
	lappend r $name [XMLRPC::TypedVariable::create "struct" $value]
    }
	
    return [XMLRPC::TypedVariable::create "struct" $r]
}

# -------------------------------------------------------------------------

# validator1.manyTypesTest (num, bool, state, doub, dat, bin) returns array
#
# This handler takes six parameters and returns an array containing
# all the parameters.
#
proc manyTypesTest {num bool state doub dat bin} {
    set r {}
    if {$bool} {set bool true} else {set bool false}
    set dat [XMLRPC::TypedVariable::create "timeInstant" $dat]
    lappend r $num $bool $state $doub $dat $bin
    return [XMLRPC::TypedVariable::create "array" $r]
}

# -------------------------------------------------------------------------

# validator1.moderateSizeArrayCheck (myArray) returns string
#
# This handler takes a single parameter named myArray, which is an
# array containing between 100 and 200 elements. Each of the items is
# a string, your handler must return a string containing the
# concatenated text of the first and last elements.

proc moderateSizeArrayCheck {myArray} {
    return "[lindex $myArray 0][lindex $myArray end]"
}

# -------------------------------------------------------------------------

# validator1.simpleStructReturnTest (myNumber) returns struct
#
# This handler takes one parameter a number named myNumber, and returns
# a struct containing three elements, times10, times100 and times1000,
# the result of multiplying the number by 10, 100 and 1000
#
proc simpleStructReturnTest {myNumber} {
    set r(times10) [expr $myNumber * 10]
    set r(times100) [expr $myNumber * 100]
    set r(times1000) [expr $myNumber * 1000]
    return [XMLRPC::TypedVariable::create "struct" [array get r]]
}

# -------------------------------------------------------------------------

# validator1.nestedStructTest (myStruct) returns number
#
# This handler takes a single parameter named myStruct, a struct, that
# models a daily calendar. At the top level, there is one struct for
# each year. Each year is broken down into months, and months into
# days. Most of the days are empty in the struct you receive, but the
# entry for April 1, 2000 contains a least three elements named moe,
# larry and curly, all <i4>s. Your handler must add the three numbers
# and return the result.
# NB: month and day are two-digits with leading 0s, and January is 01
#
proc nestedStructTest {myStruct} {
    set result 0
    foreach {year months} $myStruct {
	if {[string match "year2000" $year]} {
	    foreach {month days} $months {
		if {[string match "month04" $month]} {
		    foreach {day stooges} $days {
			if {[string match "day01" $day]} {
			    foreach {stooge value} $stooges {
				switch -- $stooge {
				    curly {incr result $value}
				    larry {incr result $value}
				    moe   {incr result $value}
				}
			    }
			}
		    }
		}
	    }
	}
    }
    return $result
}
				    

# -------------------------------------------------------------------------

# Description:
#   Given the nested structure provided for the nestedStructTest, 
#   echo the struct back to the caller.
# Notes:
#   This is not one of the required tests, but writing this exposed some
#   issues in handling nested structures within the TclSOAP framework. It
#   works now. However, this implementation will not ensure that the structure
#   members are returned in the same order that they were provided.
#
proc echoNestedStructTest {myStruct} {
    global years
    array set years {}
    foreach {name value} $myStruct {
	set years($name) [year $value]
    }
    return [XMLRPC::TypedVariable::create struct [array get years]]
}

proc year {yearValue} {
    array set months {}
    foreach {name value} $yearValue {
	set months($name) [month $value]
    }
    return [XMLRPC::TypedVariable::create struct [array get months]]
}

proc month {monthValue} {
    array set days {}
    foreach {name value} $monthValue {
	set days($name) [day $value]
    }
    return [XMLRPC::TypedVariable::create struct [array get days]]
}

proc day {dayValue} {
    array set stooges {}
    foreach {name value} $dayValue {
	set stooges($name) $value
    }
    return [XMLRPC::TypedVariable::create struct [array get stooges]]
}

# -------------------------------------------------------------------------

#
# Local variables:
# mode: tcl
# End:
