# tclhttpd-validator.tcl - 
#    Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
#   This file creates the SoapWare.org SOAP and XML-RPC validation suites
#   under TclHTTPd.
#
#   As of TclSOAP 1.6.8 this code will register the /validate endpoint
#   for use with both SOAP and XML-RPC. The cgi-bin/soap/validator.tcl 
#   file is a dual mode implementation - able to provide the correct
#   responses for either protocol.
#
# $Id$

# Find our implementation of the webservice.
set Validator [file normalize [file join [file dirname [info script]] \
                                   .. cgi-bin soap validator.tcl]]

# Connect the service to the /validate endpoint
package require SOAP::Domain
source $Validator
SOAP::Domain::register -prefix /validate

# Demonstrate the provision of a service in a safe interpreter.

# We have to use the following command to create the interp to work around
# filename length limitations in the Safe package.
# This also adds the script directory into those permitted for the safe
# interpreter to source from.
set slave [SOAP::CGI::createInterp {} [file dirname $Validator]]

catch {$slave eval package require SOAP}
$slave eval {
    package require SOAP
    package require SOAP::CGI
    package require SOAP::Domain
}
$slave eval [list source $Validator]
SOAP::Domain::register -prefix /safevalidate -interp $slave