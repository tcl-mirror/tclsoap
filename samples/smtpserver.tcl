#! /bin/sh
#
# smtpserver - Copyright (C) 2001 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Sample SOAP SMTP endpoint.
#
# This listens on the designated port and pops up a messagebox with the SOAP
# request result.
#
# $Id$
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the file 'license.terms' for
# more details.
# -------------------------------------------------------------------------
# \
exec wish8.3 "$0" ${1+"$@"}

package require SOAP::CGI
package require smtpd
package require Tk
wm withdraw .

set SOAP::CGI::soapmapfile [file join [pwd] .. cgi-bin soapmap.dat]
set SOAP::CGI::soapdir   [file join [pwd] .. cgi-bin soap]

set SOAP::CGI::xmlrpcmapfile [file join [pwd] .. cgi-bin xmlrpcmap.dat]
set SOAP::CGI::xmlrpcdir [file join [pwd] .. cgi-bin soap]

set SOAP::CGI::debugging 1

# Handle new mail by raising a message dialog for each recipient.
proc deliver {sender recipients data} {
    if {[catch {eval array set saddr [mime::parseaddress $sender]}]} {
        error "invalid sender address \"$sender\""
    }
    set mail "From $saddr(address) [clock format [clock seconds]]"
    foreach rcpt $recipients {
        if {! [catch {eval array set addr [mime::parseaddress $rcpt]}]} {
            append mail "\n" "To: $addr(address)"
        }
    }
    append mail "\n" [join $data "\n"]
    set ::soapmail $mail

    set tok [mime::initialize -string $mail]
    set payload [mime::getbody $tok]

    array set params [mime::getproperty $tok]
    if {$params(encoding) == "quoted-printable"} {
        set payload [mime::qp_decode $payload]
    }
    
    catch {SOAP::CGI::main $payload 1} res
    tk_messageBox -title "SOAP Req" -message "Result: $res"

    mime::finalize $tok
}

# Accept everyone except those spammers on 192.168.1.* :)
proc validate_host {ipnum} {
    if {[string match "192.168.1.*" $ipnum]} {
        error "your domain is not allowed to post, Spammers!"
    }
}

# Accept mail from anyone except user 'denied'
proc validate_sender {address} {
    eval array set addr [mime::parseaddress $address]
    if {[string match "denied" $addr(local)]} {
        error "mailbox $addr(local) denied"
    }
    return    
}

# Only reject mail for recipients beginning with 'bogus'
proc validate_recipient {address} {
    eval array set addr [mime::parseaddress $address]
    if {[string match "bogus*" $addr(local)]} {
        error "mailbox $addr(local) denied"
    }
    return
}

# Setup the mail server
smtpd::configure \
    -deliver            ::deliver \
    -validate_host      ::validate_host \
    -validate_recipient ::validate_recipient \
    -validate_sender    ::validate_sender

# Run the server on the default port 25. For unix change to 
# a high numbered port eg: 2525 or 8025 etc with
# smtpd::start 127.0.0.1 8025 or smtpd::start 0.0.0.0 2525

set iface 0.0.0.0
set port 25

if {$argc > 0} {
    set iface [lindex $argv 0]
}
if {$argc > 1} {
    set port [lindex $argv 1]
}

if {$::tcl_interactive} {
    puts "You probably want to type \"smtpd::start 0.0.0.0 25\" or something"
} else {
    smtpd::start $iface $port
}

#
# Local variables:
#  mode: tcl
#  indent-tabs-mode: nil
# End:
