# soapserver - Copyright (C) 2001 Pat Thoyts <pat@zsplat.freeserve.co.uk>
#
# Provide a SOAP demo service. base64 encode a string.

package provide SOAP::Service 1.0

package require Trf

namespace eval SOAP::Service {
    variable version 1.0
    variable rcs_version { $Id$ }
    variable socket {}
    variable default_port 8001
}

proc SOAP::Service::start { {port {}} } {
    variable socket
    variable default_port

    if { $port == {} } {
	set port $default_port
    }
    set socket [socket -server [namespace current]::service $port]
}

proc SOAP::Service::stop {} {
    variable socket
    close $socket
}

proc SOAP::Service::gen_reply {} {
    set doc [dom::DOMImplementation create]
    set env [dom::document createElement $doc "SOAP-ENV:Element"]
    dom::element setAttribute $env \
	    "xmlns:SOAP-ENV" "http://schemas.xmlsoap.org/soap/envelope/"
    dom::element setAttribute $env \
	    "xmlns:xsi"      "http://www.w3.org/1999/XMLSchema-instance"
    dom::element setAttribute $env \
	    "xmlns:xsd"      "http://www.w3.org/1999/XMLSchema"
    set bod [dom::document createElement $env "SOAP-ENV:Body"]
    set cmd [dom::document createElement $bod "zsplat:getBase64"]
    dom::element setAttribute $cmd "xmlns:zsplat" "urn:zsplat-Base64"
    dom::element setAttribute $cmd \
	    "SOAP-ENV:encodingStyle" "http://schemas.xmlsoap.org/soap/encoding/"
    set par [dom::document createElement $cmd "return"]
    dom::element setAttribute $par "xsi:type" "xsd:string"
    dom::document createTextNode $par [base64 -mode enc "This is a result."]
    return $doc
    
}

proc SOAP::Service::service {channel client_addr client_port} {
    set data {1}
    while { $data != {} && ! [eof $channel] } {
	gets $channel data
	puts "$data"
    }
    
    set reply [[namespace current]::gen_reply]
    set body [dom::DOMImplementation serialize $reply]
    set head [join [list \
	    "HTTP/1.1 200 OK" \
	    "Content-Type: text/xml" \
	    "Content-Length: [string length $body]"\
	    "" ] "\n" ]
    
    puts $channel "${head}\n${body}"
    flush $channel
    close $channel
}
