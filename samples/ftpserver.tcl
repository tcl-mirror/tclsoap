package require ftpd;                   # tcllib 1.1

namespace eval SOAP::ftpd {
    variable id

    if {![info exists id]} {
        set id 0
    }
}

proc SOAP::ftpd::authUsr {user passwd} {
    variable id
    return 1
}

proc SOAP::ftpd::authFile {user path op} {
    if {$op == "write"} {
        return 1
    } else {
        return 0
    }
}

#proc SOAP::ftpd::fsCmd {cmd path args} {
#    switch -exact -- $cmd {
#        store {
#            return stdin
#        }
#        default {
#            return [::ftpd::fsFile::fs $cmd $path $args]
#        }
#    }
#}

ftpd::config -authUsrCmd ::SOAP::ftpd::authUsr \
    -authFileCmd ::SOAP::ftpd::authFile \
    -fsCmd ::SOAP::ftpd::fsCmd

ftpd::server
