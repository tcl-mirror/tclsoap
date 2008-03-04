# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded SOAP 1.6.7.1 [list source [file join $dir SOAP.tcl]]
package ifneeded SOAP::CGI 1.0.1 [list source [file join $dir SOAP-CGI.tcl]]
package ifneeded SOAP::Domain 1.4.1 [list source [file join $dir SOAP-domain.tcl]]
package ifneeded SOAP::Service 0.5 [list source [file join $dir SOAP-service.tcl]]
package ifneeded SOAP::Utils 1.1 [list source [file join $dir utils.tcl]]
package ifneeded SOAP::ftp 1.0 [list source [file join $dir ftp.tcl]]
package ifneeded SOAP::http 1.0 [list source [file join $dir http.tcl]]
package ifneeded SOAP::https 1.0 [list source [file join $dir https.tcl]]
package ifneeded SOAP::smtp 1.0 [list source [file join $dir smtp.tcl]]
package ifneeded SOAP::xpath 0.2 [list source [file join $dir xpath.tcl]]
package ifneeded XMLRPC 1.0.1 [list source [file join $dir XMLRPC.tcl]]
package ifneeded rpcvar 1.2 [list source [file join $dir rpcvar.tcl]]
package ifneeded soapinterop::base 1.0 [list source [file join $dir interop soapinterop.tcl]]
package ifneeded soapinterop::B 1.0 [list source [file join $dir interop soapinteropB.tcl]]
package ifneeded soapinterop::C 1.0 [list source [file join $dir interop soapinteropC.tcl]]
