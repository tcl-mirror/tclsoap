# Create the commands for my XMLRPC-domain package

package require XMLRPC
set methods {}

lappend methods [ XMLRPC::create rcsid \
		      -name rcsid \
		      -uri zsplat-Test \
		      -proxy http://localhost:8015/rpc/rcsid \
		      -params {} ]

lappend methods [ XMLRPC::create zbase64 \
		      -name base64 \
		      -uri zsplat-Test \
		      -proxy http://localhost:8015/rpc/base64 \
		      -params {msg string} ]

lappend methods [ XMLRPC::create ztime \
		      -name time \
		      -uri zsplat-Test \
		      -proxy http://localhost:8015/rpc/time \
		      -params {} ]

lappend methods [ XMLRPC::create square \
		      -uri zsplat-Test \
		      -proxy http://localhost:8015/rpc/square \
		      -params {num integer} ]

lappend methods [ XMLRPC::create sort \
		      -uri zsplat-Test \
		      -proxy http://localhost:8015/rpc/sort \
		      -params { list string } ]

lappend methods [ XMLRPC::create platform \
		      -uri zsplat-Test \
		      -proxy http://localhost:8015/rpc/platform \
		      -params {} ]

puts "$methods"
unset methods
