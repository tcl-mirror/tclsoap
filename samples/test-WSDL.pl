# test-WSDL.pl Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Check out TclSOAP's interop WSDL file using SOAP::Lite.
#

use SOAP::Lite;

my $service = SOAP::Lite
  ->service('http://tclsoap.sourceforge.net/WSDL/silab.wsdl');

$voidResponse = $service->echoVoid();
$voidResponse = '' unless defined $voidResponse;
print "echoVoid: \"$voidResponse\"\n";
print "echoString: " . $service->echoString('Hello, TclSOAP') . "\n";
print "echoInteger: " . $service->echoInteger(3) . "\n";
print "echoFloat: " . $service->echoFloat(2.1) . "\n";

$strings = $service->echoStringArray(['Hello','Tcl','SOAP']);
print "echoStringArray: \"" . join("\", \"", @$strings) . "\"\n";

$ints = $service->echoIntegerArray([45, 2, -18, 0]);
print "echoIntegerArray: " . join(', ', @$ints) . "\n";

$floats = $service->echoFloatArray([4.5, -2.0, 0, 3e-2]);
print "echoFloatArray: " . join(', ', @$floats) . "\n";

$struct = $service->echoStruct({varInt=>120,
                                varFloat=>3.1415,
                                varString=>"soopa"});
print "echoStruct: {\n";
foreach $membr (keys %$struct) {
  print "    $membr => $struct->{$membr}\n";
}
print "};\n";

exit;

