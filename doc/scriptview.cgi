#!/bin/sh
#
# scriptview.cgi = Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# Present a named Tcl script file over HTTP. Include some font-lock style 
# syntax colouring.
#
# The regular expression segment needs work to mask syntax elements within
# comments / quoted strings. Otherwise it looks good.
#
# restart with tclsh \
exec tclsh "$0" ${1+"$@"}

# -------------------------------------------------------------------------
# << configure me >>
# -------------------------------------------------------------------------

# Point to our installation of tcllib etc.
#set auto_path [linsert $auto_path 0 [file join [pwd] "../../.."]]
#set auto_path [linsert $auto_path 0 [file join [pwd] "../lib/tcl/tcllib0.8"]]
set auto_path [linsert $auto_path 0 /home/pat/lib/tcl \
	/home/pat/lib/tcl/tcllib0.8]

# This is the filesystem root and list of permissible script names.
#set root [file join [pwd] "../../../tclsoap"]
#set root [file join [pwd] "../tclsoap"]
set root /home/pat/lib/tcl/tclsoap

# -------------------------------------------------------------------------

set permitted {SOAP.tcl SOAP-domain.tcl SOAP-parse.tcl SOAP-service.tcl \
	       xpath.tcl XMLRPC.tcl XMLRPC-domain.tcl XMLRPC-typed.tcl \
	       samples/SOAP-tests.tcl samples/XMLRPC-tests.tcl }

proc SV_subst {body} {
    regsub -all {\\([][{}\\])} $body {\1} body
    return $body
}

proc SV_plain {body} {
    puts -nonewline "[SV_subst $body]"
}

proc SV_comment {text {body {}}} {
    set r {}
    foreach elt $text {
	if { ! [string match SV_* $elt] } { append r $elt }
    }
    puts -nonewline "<font color=\"red\">[SV_subst $r]</font>[SV_subst $body]"
}

proc SV_string {text {body {}}} {
    set r {}
    foreach elt $text {
	if { ! [string match SV_* $elt] } { append r $elt }
    }
    puts -nonewline "<font color=\"salmon\">[SV_subst $r]</font>[SV_subst $body]"
}

proc SV_function {type name param rest} {
    puts -nonewline "<font color=\"blue\">$type</font> <font color=\"magenta\">$name</font>${param}[SV_subst $rest]"
}

proc SV_keyword {text body} {
    puts -nonewline "<font color=\"blue\">[SV_subst $text]</font>[SV_subst $body]"
}

proc SV_variable {text rest} {
    puts -nonewline "<font color=\"green\">[SV_subst $text]</font>[SV_subst $rest]"
}

proc SV_fontify {data} {
    regsub -all {[][{}\\]} $data {\\&} data

    # Protect quoted strings, then protect HTML special characters
    regsub -all "\"" $data {zQuOtE} data
    set data [html::quoteFormValue $data]
    regsub -all {zQuOtE} $data "\"" data

    # Emacs W3 browser needs a newline added after the comments. I don't know about
    # netscape.
    set comment_fix {}
    if {[string match {Emacs-W3*} $::env(HTTP_USER_AGENT)]} {
	set comment_fix "\n"
    }
	
    regsub -all "\#\[^\n\]*\n" $data \
	    "\}\nSV_comment {{&${comment_fix}}} \{" data
    #regsub -all {"[^"]*"} $data "\}\nSV_string {{&}} \{" data ;#"
    regsub -all \
	    "(proc)\[ \t\]+(\[^ \t\]+)"\
	    $data "\}\nSV_function {\\1} {\\2} {\\3} \{" data

    regsub -all [join [list \
	    "(\\\\?\[\]\[{} \t\n\r:;\])" \
            {(break|case|continue|default|e((lse|lseif)|rror|val|xit)}\
	    {|for|for_(array_keys|file|recursive_glob)|foreach}\
	    {|i([fn]|tcl_class)|loop|namespace e(val|xport)}\
	    {|package (provide|require)|return}\
	    {|switch|then|uplevel|while)} \
            "(\\\\?\[ \t\r\n:;\])" ] {}] \
	    $data "\}\nSV_keyword {&} \{" data

    regsub -all [join [list \
	    "(\\\\?\[\]\[{} \t\n\r:;\])" \
	    {(common|global|inherit|p(r(ivate|otected)|ublic)}\
	    {|upvar|variable)} \
            "(\\\\?\[ \t\r\n:;\])" ] {}] \
	    $data "\}\nSV_variable {&} \{" data

    #puts "<pre>SV_plain { $data }</pre><h1>[string repeat - 76]</h1>"
    return $data
}

proc log {data} {
    set f [open /tmp/scriptview.log w]
    puts -nonewline $f [list $data]
    close $f
}

if { [catch {

    package require ncgi
    package require html

    set query [ncgi::nvlist]
    set scriptname [lindex $query 1]
    if { [lsearch $permitted $scriptname] == -1 } {
	error "Permission denied: \"$scriptname\" must be one of \"$permitted\"" {} CGI
    }
    set filename [file join $root $scriptname]
    if { ! [file exists $filename] } {
	error "file not found: \"$scriptname\" does not exist under $root" {} CGI
    }

    # Read in the script contents
    set f [open $filename r]
    set data [read $f]
    close $f

    ncgi::header text/html {}
#    [list "Last Modified" [clock format [file mtime $filename]]]
    puts "<html><head><title>$scriptname</title></head>"
    flush stdout

    set data [SV_fontify $data]
    puts "<body bgcolor=\"\#ffffff\" text=\"\#000000\">"
    puts -nonewline "<pre>"
    log "\{$data\}"
    eval "SV_plain \{$data\}"
    puts "</pre><br>"
    puts -nonewline "<font size=\"-1\"># Generated by <em>scriptview.cgi</em> "
    puts "on [clock format [clock seconds]] "
    puts "using tcl ${tcl_patchLevel}."
    puts "</font></body></html>"

    flush stdout
    exit 0

} msg] } {

    puts "Content-Type: text/html\n"
    puts "<h1>Error During CGI Script Execution</h1><p>$msg</p>"
    if { $errorCode != "CGI" } {
	puts "<p>Additional information:<pre>$errorInfo</pre></p>"
    }

}


#
# Local variables:
# mode: tcl
# End:
