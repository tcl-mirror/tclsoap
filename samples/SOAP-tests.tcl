# SOAP-tests.tcl - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Create some remote SOAP access methods to demo servers.
#
# The SOAP::Lite project has some nice examples of object access that
# we should pursue
# 
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the accompanying file `LICENSE'
# for more details.
# -------------------------------------------------------------------------
#
# @(#)$Id: SOAP-tests.tcl,v 1.7 2001/03/17 01:21:49 pat Exp pat $

package require SOAP 1.0

# -------------------------------------------------------------------------
#
# XMethods demos (www.xmethods.net)
#
SOAP::create getTemp \
        -uri "urn:xmethods-Temperature" \
        -proxy "http://services.xmethods.net/soap/servlet/rpcrouter" \
        -params { "zipcode" "string" }

SOAP::create pingHost \
        -proxy "http://services.xmethods.net:80/perl/soaplite.cgi" \
        -uri "urn:xmethodsSoapPing" \
        -params { "hostname" "string" }

SOAP::create getTraffic \
        -proxy "http://services.xmethods.net:80/soap/servlet/rpcrouter" \
        -uri "urn:xmethods-CATraffic" \
        -params { "hwaynum" "string" }

SOAP::create checkDomain \
        -uri "urn:xmethods-DomainChecker" \
        -proxy "http://services.xmethods.net:9090/soap" \
        -params { "domainname" "string" }

# -------------------------------------------------------------------------
#
# SOAP::Lite Perl demos (www.soaplite.com)
#
SOAP::create hi \
        -uri "http://www.soaplite.com/Demo" \
        -proxy "http://services.soaplite.com/hibye.cgi" \
        -params {}

SOAP::create hello \
        -name hi \
        -uri "http://www.soaplite.com/Demo" \
        -proxy "http://services.soaplite.com/hibye.cgi" \
        -params {}

SOAP::create languages \
        -uri "http://www.soaplite.com/Demo" \
        -proxy "http://services.soaplite.com/hibye.cgi" \
        -params {}

SOAP::create f2c \
        -uri "http://www.soaplite.com/Temperatures" \
        -proxy "http://services.soaplite.com/temper.cgi" \
        -params { "temp" "float"}

SOAP::create c2f \
        -uri "http://www.soaplite.com/Temperatures" \
        -proxy "http://services.soaplite.com/temper.cgi" \
        -params { "temp" "float"}

# Call with the wrong method name evokes a SOAP Fault packet.
SOAP::create c2f_broke \
        -uri "http://www.soaplite.com/Temperatures" \
        -proxy "http://services.soaplite.com/temper.cgi" \
        -params { "temp" "float"}\
        -name c2f_invalid

# -------------------------------------------------------------------------
#
# Lucin
#
SOAP::create getCard \
        -uri "GetACard" \
        -name "GetACard" \
        -proxy "http://sal006.salnetwork.com:82/bin/games.cgi" \
        -params {}

SOAP::create getHand \
        -uri "GetAHand" \
        -name "GetAHand" \
        -proxy "http://sal006.salnetwork.com:82/bin/games.cgi" \
        -params {}

# -------------------------------------------------------------------------
#
# Other demos
#
SOAP::create NextGUID \
        -uri "http://www.itfinity.net/soap/guid/guid.xsd" \
        -proxy "http://www.itfinity.net/soap/guid/default.asp" \
        -params {}

SOAP::create whois \
        -uri "http://www.pocketsoap.com/whois" \
        -proxy "http://www.razorsoft.net/ssss4c/whois.asp" \
        -params { "name" "string" }

SOAP::create census \
        -uri "http://tempuri.org/" \
        -proxy "http://terranet.research.microsoft.com/CensusService.asmx" \
        -params { "pu" "string" "name" "string" \
                  "ParentName" "string" "year" "integer" } \
        -action "http://tempuri.org/GetPoliticalUnitFactsByName" \
        -name GetPoliticalUnitFactsByName


# Babelfish translator http://www.xmltoday.com/examples/soap/translate.psp

SOAP::create translate \
        -action urn:vgx-translate \
        -name getTranslation \
        -proxy http://www.velocigen.com:82/vx_engine/soap-trigger.pperl \
        -uri urn:vgx-translate \
        -params {"text" "string" "language" "string"}

# translate {Good morning} en_[de|fr|it|es|pt]
# translate {Guten tag} de_fr

# -------------------------------------------------------------------------

# Fortune server has 3 methods.
namespace eval Fortune {
    variable uri "urn:lemurlabs-Fortune"
    variable proxy "http://www.lemurlabs.com:80/rpcrouter"
    SOAP::create getAnyFortune -uri $uri -proxy $proxy
    SOAP::create getDictionaryNameList -uri $uri -proxy $proxy
    SOAP::create getFortuneByDictionary -uri $uri -proxy $proxy \
            -params { "dictionary" "string" }
    namespace export getAnyFortune getDictionaryNameList \
            getFortuneByDictionary
}

# -------------------------------------------------------------------------

namespace eval XFS {
    variable uri "urn:xmethodsXFS"
    variable proxy "http://services.xmethods.net:80/soap/servlet/rpcrouter"
    SOAP::create readFile -uri $uri -proxy $proxy -params \
            { "userid" "string" "filename" "string" "password" "string" }
    SOAP::create writeFile -uri $uri -proxy $proxy -params \
            { "userid" "string" \
            "filedata" "string" \
            "filename" "string" \
            "password" "string" }
    SOAP::create removeFile -uri $uri -proxy $proxy -params \
            { "userid" "string" "filename" "string" "password" "string" }
    SOAP::create listFiles -uri $uri -proxy $proxy -params \
            { "userid" "string" "password" "string" }
    namespace export readFile removeFile writeFile listFiles
}

namespace eval Chat {
    variable uri "http://tempuri.org/"
    variable proxy "http://aspx.securewebs.com/prasadv/prasadchat.asmx"
    SOAP::create RegisterMember -uri $uri -proxy $proxy \
            -action "${uri}RegisterMember" \
            -params { "NickName" "string" }
    SOAP::create XchangeMsgs -uri $uri -proxy $proxy \
            -action "${uri}XchangeMsgs" \
            -params { "NickName" "string" "Msg" "string" }
    SOAP::create GetMsgs -uri $uri -proxy $proxy \
            -action "${uri}GetMsgs" \
            -params { "NickName" "string" }
    namespace export RegisterMember XchangeMsgs GetMsgs
}

# -------------------------------------------------------------------------

# Setup SOAP HTTP transport for our authenticating proxy
# This is used for me to test at work.

proc SOAP::proxyconfig {} {
    package require Trf
    toplevel .t
    wm title .t "Proxy Configuration"
    set m [message .t.m1 -relief groove -justify left -width 6c -aspect 200 \
            -text "Enter details of your proxy server (if any) and your username and password if it is needed by the proxy."]
    set f1 [frame .t.f1]
    set f2 [frame .t.f2]
    button $f2.b -text "OK" -command {destroy .t}
    pack $f2.b -side right
    label $f1.l1 -text "Proxy (host:port)"
    label $f1.l2 -text "Username"
    label $f1.l3 -text "Password"
    entry $f1.e1 -textvariable SOAP::conf_proxy
    entry $f1.e2 -textvariable SOAP::conf_userid
    entry $f1.e3 -textvariable SOAP::conf_passwd -show {*}
    grid $f1.l1 -column 0 -row 0 -sticky e
    grid $f1.l2 -column 0 -row 1 -sticky e
    grid $f1.l3 -column 0 -row 2 -sticky e
    grid $f1.e1 -column 1 -row 0 -sticky news
    grid $f1.e2 -column 1 -row 1 -sticky news
    grid $f1.e3 -column 1 -row 2 -sticky news
    grid columnconfigure $f1 1 -weight 1
    pack $f2 -side bottom -fill x
    pack $m  -side top -fill x -expand 1
    pack $f1 -side top -anchor n -fill both -expand 1
    tkwait window .t
    SOAP::configure -transport http -proxy $SOAP::conf_proxy
    if { [info exists SOAP::conf_userid] } {
        SOAP::configure -transport http \
            -headers [list "Proxy-Authorization" \
            "Basic [lindex [base64 -mode enc ${SOAP::conf_userid}:${SOAP::conf_passwd}] 0]" ]
    }
    unset SOAP::conf_passwd
}

SOAP::proxyconfig

# Local variables:
#   indent-tabs-mode: nil
# End: