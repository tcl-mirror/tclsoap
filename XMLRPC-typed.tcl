# XMLRPC-typed.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide a mechanism for passing hints as to the XML-RPC value type from
# the user code to the XML-RPC framework.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package provide XMLRPC::TypedVariable 1.1

namespace eval XMLRPC::TypedVariable {
    variable version 1.1
    variable magic {XTVar}
    variable rcs_id {$Id: XMLRPC-typed.tcl,v 1.3 2001/07/16 23:44:48 patthoyts Exp $}

    namespace export create destroy is_typed_variable get_type get_value \
            get_subtype
    
}

# -------------------------------------------------------------------------

# Description:
#   Create a typed variable.
# Parameters:
#   type    - the XML-RPC type of this value
#   value   - the value being typed
# Result:
#   Returns a reference to the newly created typed variable
#
proc XMLRPC::TypedVariable::create { type value } {
    variable magic
    set typed [list $magic $type $value]
    return $typed
}

# rpcval ?-namespace soap-uri? type value
proc rpcval {args} {
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

    return [list XTVar2 $xmlns [lindex $args 0] [lindex $args 1]]
}

# -------------------------------------------------------------------------

# Description:
#   Destroy a typed variable
# Parameters:
#   varref - The reference to the typed variable to destroy
# Result:
#   The typed variable is deleted.
#   Returns nothing or raises an exception on error.
#
proc XMLRPC::TypedVariable::destroy { varref } {
    return
}

# -------------------------------------------------------------------------

# Description:
#   Examine a variable to see if is a reference to a typed variable
# Parameters:
#   varref - reference to the object to be tested
# Result:
#   Returns 1 if the object is a typed value or 0 if not
#
proc XMLRPC::TypedVariable::is_typed_variable { varref } {
    variable magic
    set failed [catch {lindex $varref 0} ref_magic]
    if { ! $failed && $ref_magic == $magic } {
        return 1
    }
    return 0
}

# -------------------------------------------------------------------------

# Description:
#   Guess the XML-RPC type of the input.
#   For some simple types we can guess the value type. For others we have
#   to use a typed variable. 
# Parameters:
#   arg  - the value for which we are trying to assign a XML-RPC type.
# Returns:
#   The XML-RPC type is one of int, boolean, double, string,
#   dateTime.iso8601, base64, struct or array. However, we only return one
#   of struct, int, double, boolean or string unless we were passed a 
#   typed variable.
#
proc XMLRPC::TypedVariable::get_type { arg } {
    set type {}
    if { [is_typed_variable $arg] } {
        regexp {([^(]+)(\([^)]+\))?} [lindex $arg 1] -> type subtype
    } elseif {[uplevel 1 array exists [list $arg]]} {
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

# If the value is not a typed variable, then there cannot be a subtype.
# otherwise we are looking for array(int) or struct(Typename) etc.
proc XMLRPC::TypedVariable::get_subtype { arg } {
    set subtype {}
    if {[is_typed_variable $arg]} {
        regexp {([^(]+)(\((.+)\))?} [lindex $arg 1] -> type -> subtype
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
proc XMLRPC::TypedVariable::get_value { arg } {
    if { [is_typed_variable $arg] } {
        return [lindex $arg 2]
    } else {
        return $arg
    }
}

# -------------------------------------------------------------------------

# Local variables:
#    indent-tabs-mode: nil
# End:
