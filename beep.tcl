# beep.tcl - Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Provide an BEEP transport for the SOAP package.
#
# BEEP support using the beepcore-tcl code from 
# http://sourceforge.net/projects/beepcore-tcl provided my M Rose.
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------

package require beepcore::log;          # beepcore-tcl
package require beepcore::mixer;        # beepcore-tcl
package require beepcore::peer;         # beepcore-tcl
package require mime;                   # tcllib

namespace eval SOAP::Transport::beep {
    variable version 1.0
    variable rcsid {$Id$}
    variable options
    variable sessions

    package provide SOAP::beep $version

    SOAP::register soap.beep  [namespace current]
    SOAP::register soap.beeps [namespace current]

    if {![info exists options]} {
        array set options [list \
            -logfile    /dev/null \
            -logident   soap \
        ]
    }

    array set sessions {}

    # beep transport options to be added to the SOAP method options.
    variable method:options {
        logT
        logfile
        logident
        mixerT
        channelT
        features
    }
}

proc SOAP::Transport::beep::method:configure {procVarName opt value} {
    upvar $procVarName procvar
    switch -glob -- $opt {
        -logT - -logfile - -logident - -mixerT - -channelT -
        -features - -destroy - -wait {
            set procvar($opt) $value
        }
        default {
            error "unknown option \"$opt\""
        }
    }
}

proc SOAP::Transport::beep::method:create {procVarName} {
    global debugP
    variable sessions
    upvar $procVarName procvar

    if { ![info exists debugP] } {
	set debugP 0
    }
    
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
	    x prefix proto host y port resource]} {
        error {use soap.beep[s]://}
    }

    # create a logging object, if necessary
    if { [set logT $procvar(logT)] == {} } {
	set logT [set procvar(logT) \
		      [::log::init $Transport::beep::options(-logfile) \
				   $Transport::beep::options(-logident)]]
    }

    ###
    # when the RFC issues, update the default port number...
    ###
    if { $port == {} } {
	set port 10288
    }
    if { $resource == {} } {
	set resource /
    }
    switch -- $scheme {
	soap.beep {
	    set privacy none
	}

	soap.beeps {
	    set privacy strong
	}
    } 
    array set options [array get [namespace current]::options]
    unset options(-logfile) \
	  options(-logident)
    array set options [list -port	$port	 \
			    -privacy	$privacy \
			    -servername $host]

    set procName [lindex [split $procVarName {_}] end]

    # see if we have a session already cached
    set signature ""
    foreach option [lsort [array names options]] {
	append signature $option $options($option)
    }
    foreach mixerT [array name sessions] {
	catch { unset props }
	array set props $sessions($mixerT)

	if { ($props(host) != $host) \
		|| ($props(resource) != $resource) \
		|| ($props(signature) != $signature) } {
	    continue
	}

	if { $procvar(mixerT) == $mixerT } {
	    ::log::entry $logT debug [info level 0] "$procName noop"

	    return
	}

	incr props(refcnt)
	set sessions($mixerT) [array get props]
	::log::entry $logT debug [info level 0] \
	     "$procName using session $mixerT, refcnt now $props(refcnt)"

	set procvar(mixerT) $mixerT
	set procvar(channelT) $props(channelT)
	set procvar(features) $props(features)

	return
    }

    # start a new session
    switch -- [catch { eval [list ::mixer::init $logT $host] \
			    [array get options] } mixerT] {
	0 {
	    set props(host) $host
	    set props(resource) $resource
	    set props(signature) ""
	    foreach option [lsort [array names options]] {
		append props(signature) $option $options($option)
	    }
	    set props(features) {}
	    set props(refcnt) 1
	    set sessions($mixerT) [array get props]

	    set procvar(mixerT) $mixerT
	    ::log::entry $logT debug [info level 0] \
		 "$procName adding $mixerT to session cache, host $host"
	}

	7 {
	    array set parse $mixerT
	    ::log::entry $logT user \
			 "mixer::init $parse(code): $parse(diagnostic)"

	    error $parse(diagnostic)
	}

	default {
	    ::log::entry $logT error mixer::init $mixerT

	    error $mixerT
	}
    }

    # create the channel
    set profile http://clipcode.org/beep/soap

    set doc [dom::DOMImplementation create]
    set bootmsg [dom::document createElement $doc bootmsg]
    dom::element setAttribute $bootmsg resource $resource
    set data [dom::DOMImplementation serialize $doc]
    if { [set x [string first [set y "<!DOCTYPE bootmsg>\n"] $data]] >= 0 } {
	set data [string range $data [expr $x+[string length $y]] end]
    }
    dom::DOMImplementation destroy $doc

    switch -- [set code [catch { ::mixer::create $mixerT $profile $data } \
			       channelT]] {
	0 {
	    set props(channelT) $channelT
	    set sessions($mixerT) [array get props]

	    set procvar(channelT) $channelT
	}

	7 {
	    array set parse $channelT
	    ::log::entry $logT user \
			 "mixer::create $parse(code): $parse(diagnostic)"

	    SOAP::destroy $procName
	    error $parse(diagnostic)
	}

	default {
	    ::log::entry $logT error mixer::create $channelT

	    SOAP::destroy $procName
	    error $channelT
	}
    }

    # parse the response
    if { [catch { ::peer::getprop $channelT datum } data] } {
	::log::entry $logT error peer::getprop $data

	SOAP::destroy $procName
	error $data
    }
    if { [catch { dom::DOMImplementation parse $data } doc] } {
	::log::entry $logT error dom::parse $doc

	SOAP::destroy $procName
	error "bootrpy is invalid xml: $doc"
    }
    if { [set node [selectNode $doc /bootrpy]] != {} } {
	catch {
	    set props(features) \
		[set [subst $procVarName](features) \
			    [set [dom::node cget $node -attributes](features)]]
	    set sessions($mixerT) [array get props]
	}

	dom::DOMImplementation destroy $doc
    } elseif { [set node [selectNode $doc /error]] != {} } {
	if { [catch { set code [set [dom::node cget $node -attributes](code)]
		      set diagnostic [getElementValue $node] }] } {
	    set code 500
	    set diagnostic "unable to parse boot reply"
	}

	::log::entry $logT user "$code: $diagnostic"

	dom::DOMImplementation destroy $doc

	SOAP::destroy $procName
	error "$code: $diagnostic"
    } else {
	dom::DOMImplementation destroy $doc

	SOAP::destroy $procName
	error "invalid protocol: the boot reply is invalid"
    }
}


proc SOAP::Transport::beep::configure {args} {
    if {[llength $args] == 0} {
        set r {}
        foreach {opt value} [array get options] {
            lappend r "-$opt" $value
        }
        return $r
    }

    foreach {opt value} $args {
        switch -- $opt {
            -logfile - -logident {
            }
            default {
                error "invalid option \"$opt\": must be \
                     \"-servers\", \"-headers\" or \"-sender\""
            }
        }
    }
    return {}
}

proc SOAP::Transport::beep::method:destroy {methodVarName} {
    variable sessions
    upvar $methodVarName procvar
    set procName [lindex [split $methodVarName {_}] end]

    set mixerT $procvar(mixerT)
    set logT   $procvar(logT)

    if {[catch {::mixer::wait $mixerT -timeout 0} result]} {
        ::log::entry $logT error mixer::wait $result
    }

    array set props $sessions($mixerT)
    if {[incr props(refcnt) -1] > 0} {
	set sessions($mixerT) [array get props]
	::log::entry $logT debug [info level 0] \
	     "$procName no longer using session $mixerT, refcnt now $props(refcnt)"
	return
    }

    unset sessions($mixerT)
    ::log::entry $logT debug [info level 0] \
	"$procName removing $mixerT from session cache"

    if { [catch { ::mixer::fin $mixerT } result] } {
	::log::entry $logT error mixer::fin $result
    }
    set procvar(mixerT) {}
}

proc SOAP::Transport::beep::xfer {procVarName url request} {
    upvar $procVarName procvar

    if {$pocvar(command) != {}} {
	set rpyV "[namespace current]::async $procVarName"
    } else {
	set rpyV {}
    }

    set mixerT   $procvar(mixerT)
    set channelT $procvar(channelT)
    set logT     $procvar(logT)

    if {[set x [string first [set y "?>\n"] $request]] >= 0 } {
	set request [string range $request [expr $x+[string length $y]] end]
    }
    set reqT [::mime::initialize -canonical application/xml -string $request]

    switch -- [set code [catch { ::peer::message $channelT $reqT \
				       -replyCallback $rpyV } rspT]] {
	0 {
	    ::mime::finalize $reqT

	    if { $rpyV != {} } {
		return
	    }

	    set content [::mime::getproperty $rspT content]
	    set response [::mime::getbody $rspT]

	    ::mime::finalize $rspT

	    if {[string compare $content application/xml]} {
		error "not application/xml reply, not $content"
	    }

	    return $response
	}

	7 {
	    array set parse [::mixer::errscan $mixerT $rspT]
	    ::log::entry $logT user "$parse(code): $parse(diagnostic)"

	    ::mime::finalize $reqT
	    ::mime::finalize $rspT
	    error "$parse(code): $parse(diagnostic)"
	}

	default {
	    ::log::entry $logT error peer::message $rspT

	    ::mime::finalize $reqT
	    error $rspT
	}
    }
}

proc SOAP::Transport::beep::async {procVarName channelT args} {
    upvar $procVarName procvar

    if { [catch { eval [list async2 $procVarName] $args } result] } {
	if { $procvar(errorCommand) != {} } {
	    set errorCommand $procvar(errorCommand)
	    if { ![catch { eval $errorCommand [list $result] } result] } {
		return
	    }
	}

	bgerror $result
    }
}

proc SOAP::Transport::beep::async2 {procVarName args} {
    upvar $procVarName procvar
    array set argv $args

    switch -- $argv(status) {
	positive {
	    set content [::mime::getproperty $argv(mimeT) content]
	    set reply [::mime::getbody $argv(mimeT)]
	    ::mime::finalize $argv(mimeT)

	    if {[string compare $content application/xml]} {
		error "not application/xml reply, not $content"
	    }

	    set reply [SOAP::invoke2 $procVarName $reply]
	    return [eval $procvar(command) [list $reply]]	
	}

	negative {
	    set mixerT $procvar(mixerT)
	    set logT $procvar(logT)

	    array set parse [::mixer::errscan $mixerT $argv(mimeT)]
	    ::log::entry $logT user "$parse(code): $parse(diagnostic)"

	    ::mime::finalize $argv(mimeT)
	    error "$parse(code): $parse(diagnostic)"
	}

	default {
	    ::mime::finalize $argv(mimeT)

	    error "not expecting $argv(status) reply"
	}
    }
}

proc SOAP::Transport::beep::wait {procVarName} {
    upvar $procVarName procvar
    ::mixer::wait $procvar(mixerT)
}

