# BabelFish.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sf.net>
#
# This file downloads the BabelFish service WSDL description, 
# parses it to generate a Tcl script for the service 
# applies a bug fix and then performs a translation of the arguments.
#
# Usage: BabelFish languages text
#   e.g: BabelFish en_fr "Good morning"
#
# You should be able to do this:
#  set babelfish [SOAP::service \
#      -wsdl http://www.xmethods.net/sd/2001/BabelFishService.wsdl]
#  BabelFishService::BabelFish en_fr {Good morning}
# but not yet.
#
#  Translation                 translationmode
#  -----------                 ----------------
#  English -> French           "en_fr"
#  English -> German           "en_de"
#  English -> Italian          "en_it"
#  English -> Portugese        "en_pt"
#  English -> Spanish          "en_es"
#  French -> English           "fr_en"
#  German -> English           "de_en"
#  Italian -> English          "it_en"
#  Portugese -> English        "pt_en"
#  Russian -> English          "ru_en"
#  Spanish -> English          "es_en"
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id: BabelFish.tcl,v 1.1.2.2 2003/02/04 22:55:35 patthoyts Exp $

package require SOAP
package require http

if {[catch {package require SOAP::WSDL}]} {

    # User doesn't have the WSDL package,  do it manually
    # The following code was generated by parsing the WSDL document
    namespace eval ::BabelFishService {
        set endpoint http://services.xmethods.net:80/perl/soaplite.cgi
        SOAP::create BabelFish -proxy $endpoint \
            -params {translationmode string sourcedata string} \
            -action urn:xmethodsBabelFish#BabelFish \
            -encoding http://schemas.xmlsoap.org/soap/encoding/ \
            -uri urn:xmethodsBabelFish
    }; # end of BabelFishService

} else {

    # Get the WSDL document (and cache the result for later)
    set wsdl_name BabelFishService.wsdl
    set url http://www.xmethods.net/sd/2001/BabelFishService.wsdl
    if {[file exists [set fname [file join $::env(TEMP) $wsdl_name]]]} {
        set f [open $fname r]
        set wsdl [read $f]
        close $f
    } else {
        set tok [http::geturl $url]
        if {[http::status $tok] eq "ok"} {
            set wsdl [http::data $tok]
            set f [open $fname w]
            puts $f $wsdl
            close $f
        }
        http::cleanup $tok
    }
    
    # Process the WSDL and generate Tcl script defining the SOAP accessors.
    set doc  [dom::DOMImplementation parse $wsdl]
    set impl [SOAP::WSDL::parse $doc]
    eval [set $impl]
    
    # Fixup the parameters (the rpcvar package needs to be enhanced for this)
    set schema {http://www.w3.org/2001/XMLSchema}
    foreach cmd [info commands ::BabelFishService::*] {
        set fixed {}
        foreach {param type} [SOAP::cget $cmd -params] {
            set type [regsub "${schema}:" $type {}]
            lappend fixed $param $type
        }
        SOAP::configure $cmd -params $fixed -schemas [list xsd $schema]
    }
}


# Make available as a command line script.
if {!$::tcl_interactive} {
    if {[info command BabelFishService::BabelFish] != {}} {
        if {[llength $argv] < 2} {
            puts "usage: [file tail $argv0] lanuage text ?...?"
            puts " eg: [file tail $argv0] en_fr Good morning"
            exit 1
        }
        
        set r [BabelFishService::BabelFish \
                   [lindex $argv 0] [lindex $argv 1]]
        puts $r
    }
}

# -------------------------------------------------------------------------
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
