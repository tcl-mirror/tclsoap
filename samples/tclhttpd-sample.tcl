# Example implementing a SOAP service under tclhttpd using
# the SOAP::Domain 1.4 package

# Load the SOAP service support framework
package require SOAP::Domain

# Use namespaces to isolate your methods
namespace eval urn:tclsoap:DomainTest {


    proc random {} {
        return [rpcvar::rpcvar float [expr {rand() * 10}]]
    }


    # We have to publish the public methods...
    SOAP::export random
}

# register this service with tclhttpd
SOAP::Domain::register \
    -prefix    /domaintest \
    -namespace urn:tclsoap:DomainTest \
    -uri       urn:tclsoap:DomainTest

# We can now connect a client and call our exported methods
# e.g.:
#  SOAP::create random \
#         -proxy http://localhost:8015/domaintest \
#         -uri urn:tclsoap:DomainTest 