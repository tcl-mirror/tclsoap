# rpcvar.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide a mechanism for passing hints as to the XML-RPC or SOAP value type
# from the user code to the TclSOAP framework.
#
# This package is intended to be imported into the SOAP and XMLRPC namespaces
# where the rpctype command can be overridden to restrict the types to the
# correct names. The client user should then be using SOAP::rpcvalue or
# XMLRPC::rpctype to assign type information.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide rpcvar 1.0

namespace eval rpcvar {
    variable version 1.0
    variable magic "rpcvar$version"
    variable rcs_id {$Id$}
    variable typedefs
    variable typens

    # Initialise the core types
    proc _init {xmlns typename} {
        variable typedefs ; variable typens
        set typedefs($typename) {}      ;# basic types have no typelist
        set typens($typename) $xmlns    ;# set the namespace for this type
    }

    if {! [info exists typedefs]} {
        _init xsd string
        _init xsd int
        _init xsd float
        _init xsd double
        _init xsd timeInstant
        _init SOAP-ENC base64
    }

    namespace export rpcvar is_rpcvar rpctype rpcsubtype rpcvalue \
            rpcnamespace typedef
}

# -------------------------------------------------------------------------

# Description:
#   Create a typed variable with optionally an XML namespace for SOAP types.
# Syntax:
#   rpcvar ?-namespace soap-uri? type value
# Parameters:
#   namespace - the SOAP XML namespace for this type
#   type      - the XML-RPC or SOAP type of this value
#   value     - the value being typed or, for struct type, either a list
#               of name-value pairs, or the name of the Tcl array.
# Result:
#   Returns a reference to the newly created typed variable
#
proc rpcvar::rpcvar {args} {
    variable magic

    set xmlns {}
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -n* {
                set xmlns [lindex $args 1]
                set args [lreplace $args 0 0]
            }
            --  { 
                set args [lreplace $args 0 0]
                break 
            }
            default { return -code error "unknown option \"[lindex $args 0]\""}
        }
        set args [lreplace $args 0 0]
    }

    if {[llength $args] != 2} {
        return -code error "wrong # args: \
                should be \"rpcvar ?-namespace uri? type value\""
    }

    set type [lindex $args 0]
    set value [lindex $args 1]

    if {[uplevel array exists [list $value]]} {
        set value [uplevel array get [list $value]]
    }
    return [list $magic $xmlns $type $value]
}

# -------------------------------------------------------------------------

# Description:
#   Examine a variable to see if is a reference to a typed variable
# Parameters:
#   varref - reference to the object to be tested
# Result:
#   Returns 1 if the object is a typed value or 0 if not
#
proc rpcvar::is_rpcvar { varref } {
    variable magic
    set failed [catch {lindex $varref 0} ref_magic]
    if { ! $failed && $ref_magic == $magic } {
        return 1
    }
    return 0
}

# -------------------------------------------------------------------------

# Description:
#   Guess the SOAP or XML-RPC type of the input.
#   For some simple types we can guess the value type. For others we have
#   to use a typed variable. 
# Parameters:
#   arg  - the value for which we are trying to assign a  type.
# Returns:
#   The XML-RPC type is one of int, boolean, double, string,
#   dateTime.iso8601, base64, struct or array. However, we only return one
#   of struct, int, double, boolean or string unless we were passed a 
#   typed variable.
#
proc rpcvar::rpctype { arg } {
    set type {}
    if { [is_rpcvar $arg] } {
        #regexp {([^(]+)(\((.+)\))?} [lindex $arg 2] -> type -> subtype
        set type [lindex $arg 2]
    } elseif {[uplevel array exists [list $arg]]} {
        set type "struct"
    } elseif {[string is integer -strict $arg]} {
        set type "int"
    } elseif {[string is double -strict $arg]} {
        set type "double"
    } elseif {[string is boolean -strict $arg]} { 
        set type "boolean"
    } else {
        set type "string"
    }
    return $type
}

# -------------------------------------------------------------------------

# Description:
#   If the value is not a typed variable, then there cannot be a subtype.
#   otherwise we are looking for array(int) or struct(Typename) etc.
# Result:
#   Either the subtype of an array, or an empty string.
#
proc rpcvar::rpcsubtype { arg } {
    set subtype {}
    if {[is_rpcvar $arg]} {
        regexp {([^(]+)(\((.+)\))?} [lindex $arg 2] -> type -> subtype
    }
    return $subtype
}

# -------------------------------------------------------------------------

# Description:
#   Retrieve the value from a typed variable or return the input.
# Parameters:
#   arg - either a value or a reference to a typed variable for which to 
#         return the value
# Result:
#   Returns the value of a typed variable.
#   If arg is not a typed variable it return the contents of arg
#
proc rpcvar::rpcvalue { arg } {
    if { [is_rpcvar $arg] } {
        return [lindex $arg 3]
    } else {
        return $arg
    }
}
# -------------------------------------------------------------------------

# Description:
#   Retrieve the xml namespace assigned to this variable. This is only used
#   by SOAP.
# Parameters:
#   arg - reference to an RPC typed variable.
# Result:
#   Returns the set namespace or an empty value is no namespace is assigned.
#
proc rpcvar::rpcnamespace { arg } {
    set xmlns {}
    if { [is_rpcvar $arg] } {
        set xmlns [lindex $arg 1]
    }
    return $xmlns
}

# -------------------------------------------------------------------------

# Description:
#   Define a SOAP type for use with the TclSOAP package. This allows you
#   to specify the SOAP XML namespace and typename for a chunk of data and
#   enables the TclSOAP client code to determine the SOAP type imformation
#   to put on request data.
# Options:
#   -enum             - flag the type as an enumerated type
#   -exists typename  - boolean true if typename is defined
#   -info typename    - return the definition of typename
# Parameters
#   typelist          - list of the type information needed to define the 
#                       new type.
#   typename          - the name of the new type
# Notes:
#   If the typename has already been defined then it will be overwritten.
#   For enumerated types, the typelist is the list of valid enumerator names.
#   Each enumerator may be a two element list, in which case the first element
#   is the name and the second is the integer value.
#
proc rpcvar::typedef {args} {
    variable typedefs
    variable typens

    set namespace {}
    set enum 0
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -n* {
                set namespace [lindex $args 1]
                set args [lreplace $args 0 0]
                if {[llength $args] == 1} {
                    if {[catch {set typens($namespace)} r]} {
                        set r {}
                    }
                    return $r
                }
            }
            -ex* {
                set typename [lindex $args 1]
                return [info exists typedefs($typename)]
            }
            -en* {
                set enum 1
            }
            -i* {
                set typename [lindex $args 1]
                if {[catch {set typedefs($typename)} typeinfo]} {
                    set typeinfo {}
                }
                return $typeinfo
            }
            --  { 
                set args [lreplace $args 0 0]
                break 
            }
            default { return -code error "unknown option \"[lindex $args 0]\""}
        }
        set args [lreplace $args 0 0]
    }

    if {[llength $args] != 2} {
        return -code error "wrong # args: should be \
                \"typedef ?-namespace uri? ?-enum? typelist typename\n\
                \                     or \"typedef ?-exists? ?-info? typename\""
    }

    set typelist [lindex $args 0]
    set typename [lindex $args 1]

    if {$enum} {
        set typedefs($typename) enum
        set enums($typename) $typelist
    } else {
        set typedefs($typename) $typelist
    }
    set typens($typename) $namespace

    return $typename
}

# -------------------------------------------------------------------------
#  typdef usage:
#
#  typedef -namespace urn:tclsoap-Test float TclFloat
#
#  typedef -enum -namespace urn:tclsoap-Test {red {green 3} {blue 9}} Colour
#
#  typedef {
#      larry     integer
#      moe       integer
#      curly     integer
#  } Stooges
#  => SOAP::create m -params {myStruct Stooges}
#  => m {larry 23 curly -98 moe 9}
#
#  typedef -namespace urn:soapinterop.org {
#      varInt    integer
#      varFloat  float
#      varString string
#  } SOAPStruct;    
#
#  => SOAP::create zm ... -params {myStruct SOAPStruct}
#  => zm {varInt 2 varFloat 2.2 varString "hello"}
#
#  typedef {
#      arrInt     int[]
#      stooges    Stooges[]
#      arrString  string[]
#      arrColours Colour[]
#  } arrStruct
#  => SOAP::create m -params {myStruct arrStruct}
#  => m {arrInt {1 2 3 4 5} \
#        stooges { \
#          {moe 1 larry 2 curly 3} \
#          {moe 1 larry 2 curly 3} \
#        } \
#        arrString {One Two Three} \
#        arrColours {red blue green}\
#    }

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
