# smtpclient.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Attempt a SOAP over SMTP test.
#
# You are going to need a mail server somewhere. You can of course just
# send this to your normal mail account -OR- you could get hold of the smtpd
# from tcllib 1.2+ and set this up as a SOAP SMTP endpoint. A sample of this
# is provided in the smtpserver.tcl file in the TclSOAP/samples directory.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# $Id$

package require SOAP
package require SOAP::smtp

SOAP::setLogLevel debug

SOAP::configure -transport mailto \
    -sender tclsoap@localhost \
    -servers localhost

SOAP::create echoInteger \
    -proxy   mailto:soap-interop@localhost \
    -uri     http://soapinterop.org/ \
    -action  http://soapinterop.org/ \
    -params { inputInteger int }

echoInteger 25

#
# Local variables:
# mode: tcl
# End:
