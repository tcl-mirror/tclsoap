# Google.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sf.net>
#
# Provide a simple(ish) Tcl interface to the Google SOAP API.
#
# Try: google spell "Larry Vriden"
#  or  google cache "http://mini.net/tcl/"
#  or  google search "TclSOAP"
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id: Google.tcl,v 1.1.2.2 2003/09/06 16:39:06 patthoyts Exp $

package require SOAP
package require uri
package require base64

# You need to register to use the Google SOAP API. You should put your key
# into $HOME/.googlekey using the line:
# set Key {0000000000000000}
source [file join $env(HOME) .googlekey]

# -------------------------------------------------------------------------

proc google {cmd args} {
    global Key Toplevels
    switch -glob -- $cmd {
        se* {
            set r [eval [list googleQuery] $args]
        }

        sp* {
            set r [GoogleSearchService::doSpellingSuggestion \
                       $Key [lindex $args 0]]
        }
        
        c* {
            set url [lindex $args 0]
            set d [GoogleSearchService::doGetCachedPage $Key $url]
            set r [base64::decode $d]
        }
        default {
            usage
        }
    }
    return $r
}

proc googleQuery {args} {
    global Key
    array set opts {start 0 max 10 filter false restrict "" safe false lang ""}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -start {set opts(start) [Pop args 1]}
            -max   {set opts(max) [Pop args 1]}
            -filter {set opts(filter) [Pop args 1]}
            -restrict {set opts(filter) [Pop args 1]}
            -safe {set opts(safe) [Pop args 1]}
            -lang* {set opts(lang) [Pop args 1]}
            --     { Pop args; break }
            default {
                set options [join [array names opts] ", -"]
                return -code error "invalid option \"$option\":\
                    should be one of -$options"
            }
        }
        Pop args
    }

    set r [GoogleSearchService::doGoogleSearch $Key $args \
               $opts(start) $opts(max) $opts(filter) \
               $opts(restrict) $opts(safe) $opts(lang) utf-8 utf-8]
    return $r
}

proc Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

proc usage {} {
    puts "usage: google search query"
    puts "       google spell text"
    puts "       google cache url"
    exit 1
}

proc set_useragent {{app {}}} {
    global tcl_platform
    set ua "Mozilla/4.0 ([string totitle $tcl_platform(platform)];\
        $tcl_platform(os)) http/[package provide http]"
    if {[string length $app] > 0} {
        append ua " " $app
    } else {
        append ua " Tcl/[package provide Tcl]"
    }
    http::config -useragent $ua
}
set_useragent "Google/1.0"


# -------------------------------------------------------------------------
# Setup the SOAP accessor methods
# -------------------------------------------------------------------------

proc setup_from_wsdl {} {
    # Get the WSDL document (local copy)
    # Also at 
    set wsdl_url http://api.google.com/GoogleSearch.wsdl
    set wsdl_name [file tail $wsdl_url]
    if {[file exists [set fname [file join $::env(TEMP) $wsdl_name]]]} {
        set f [open $fname r]
        set wsdl [read $f]
        close $f
    } else {
        set tok [http::geturl $wsdl_url]
        if {[http::status $tok] eq "ok"} {
            set wsdl [http::data $tok]
            set f [open $fname w]
            puts $f $wsdl
            close $f
        }
        http::cleanup $tok
    }
    
    # Process the WSDL and generate Tcl script defining the SOAP accessors.
    # This is going to change in the near future.
    set doc  [dom::DOMImplementation parse $wsdl]
    set impl [SOAP::WSDL::parse $doc]
    uplevel #0 [set $impl]
    
    # Fixup the parameters (the rpcvar package needs to be enhanced for this
    # but this hasn't been done yet)
    set schema {http://www.w3.org/2001/XMLSchema}
    foreach cmd [info commands ::GoogleSearchService::*] {
        set fixed {}
        foreach {param type} [SOAP::cget $cmd -params] {
            set type [regsub "${schema}:" $type {}]
            lappend fixed $param $type
        }
        SOAP::configure $cmd -params $fixed -schemas [list xsd $schema]
    }
}

proc setup_manually {} {
    # User doesn't have the WSDL package,  do it manually
    # The following code was generated by parsing the WSDL document
    namespace eval ::GoogleSearchService {
        set endpoint http://api.google.com/search/beta2
        set schema http://www.w3.org/2001/XMLSchema
        SOAP::create doGetCachedPage \
            -proxy $endpoint -params {key string url string} \
            -action urn:GoogleSearchAction \
            -encoding http://schemas.xmlsoap.org/soap/encoding/ \
            -schema [list xsd $schema] \
            -uri urn:GoogleSearch
        SOAP::create doSpellingSuggestion \
            -proxy $endpoint -params {key string phrase string} \
            -action urn:GoogleSearchAction \
            -encoding http://schemas.xmlsoap.org/soap/encoding/ \
            -schema [list xsd $schema] \
            -uri urn:GoogleSearch
        SOAP::create doGoogleSearch -proxy $endpoint \
            -params {key string q string start int maxResults int \
                         filter boolean restrict string safeSearch boolean \
                         lr string ie string oe string} \
            -action urn:GoogleSearchAction \
            -encoding http://schemas.xmlsoap.org/soap/encoding/ \
            -schema [list xsd $schema] \
            -uri urn:GoogleSearch
    }; # end of GoogleSearchService
}

# -------------------------------------------------------------------------
#
# Try to setup the Google API from the WSDL document. If this fails, or
# was have a version < 1.6.7 then use the manual setup.
#

proc setup {} {
    set need_setup 1

    catch {package require SOAP::WSDL}
    if {[package provide SOAP::WSDL] != {}} {
        if {[set need_setup [catch {setup_from_wsdl} msg]]} {
            puts stderr "failed to parse wsdl: $msg"
        }
    }
    
    if {$need_setup} {
        setup_manually
    }
}

# -------------------------------------------------------------------------

# Make available as a command line script.
if {!$::tcl_interactive} {
    if {[llength $argv] < 2} {
        usage
    }
    setup
    if {[info command GoogleSearchService::doGoogleSearch] != {}} {
        set r [eval [list google] $argv]
        puts $r
    }
}

# -------------------------------------------------------------------------
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
