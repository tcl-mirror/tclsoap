# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded SOAP 1.4 [list source [file join $dir SOAP.tcl]]
package ifneeded SOAP::Domain 1.0 [list source [file join $dir SOAP-domain.tcl]]
package ifneeded SOAP::Parse 1.0 [list source [file join $dir SOAP-parse.tcl]]
package ifneeded SOAP::Service 0.4 [list source [file join $dir SOAP-service.tcl]]
package ifneeded SOAP::xpath 0.2 [list source [file join $dir xpath.tcl]]
package ifneeded XMLRPC 1.0 [list source [file join $dir XMLRPC.tcl]]
package ifneeded XMLRPC::Domain 1.0 [list source [file join $dir XMLRPC-domain.tcl]]
package ifneeded XMLRPC::TypedVariable 1.0 [list source [file join $dir XMLRPC-typed.tcl]]
