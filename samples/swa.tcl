# Test SOAP-with-attachments within tclhttpd.
#
# Client:
#   SOAP::create check -uri urn:tclsoap:SWA \
#      -proxy http://localhost:8015/swa
#      -params {}

# Load the SOAP service support framework
package require SOAP::Domain
package require mime

# Use namespaces to isolate your methods
namespace eval urn:tclsoap:SWA {

    proc check {num {mime {}}} {
        if {$mime != {}} {
            set parts [mime::getproperty $mime parts]
            foreach part [lrange $parts 1 end] {
                puts stderr [mime::getproperty $part content]
            }
        }
        return $num
    }

    SOAP::export check
}

SOAP::Domain::register \
    -pregix /swa \
    -namespace urn:tclsoap:SWA \
    -uri       urn:tclsoap:SWA

