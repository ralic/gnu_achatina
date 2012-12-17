# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Session
#
# This class handles client-side session storage.
#
# Example:
#
# > method do_get {request session config} {
# >     $session set_param foobar 123
# >     return [$session get_param foobar]
# > }
#
#
oo::class create ::Achatina::Session {
    # Constructor: new
    #
    # You don't have to construct session object, it is always created for you.
    constructor {request config_} {
        package require base32

        namespace path ::tcl::mathop

        variable params {}
        variable secret_key {}
        variable config $config_

        set interface_in [$request get_interface_in__]
        set cookie [$interface_in get_cookie [dict get $config app session cookie_name]]
        set secret_key [dict get $config app session secret_key]

        # Is cookie present?
        if {($cookie ne "") && [dict exists $cookie b32] && [dict exists $cookie s]} {
            # Yep, it is

            set params_base32 [dict get $cookie b32]
            set params_signature [dict get $cookie s]
            set session_algorithm [dict get $config app session secret_key]
            set remote_addr [$request get_header REMOTE_ADDR]

            # Replace all "-" with "=" to make this string valid BASE32
            regsub -all -- {-} $params_base32 {=} params_base32

            # Validate cookie's signature and decode BASE32-encoded body of cookie
            switch [dict get $config app session algorithm] {
                sha256 {
                    package require sha2

                    if {[::sha2::hmac -hex -key "$secret_key $remote_addr" $params_base32] eq $params_signature} {
                        set params [::base32::decode $params_base32]
                        set params_output_dict $cookie
                    } else {
                        return
                    }
                }

                ripemd160 {
                    package require ripemd160

                    if {[::ripemd::hmac160 -hex -key "$secret_key $remote_addr" $params_base32] eq $params_signature} {
                        set params [::base32::decode $params_base32]
                        set params_output_dict $cookie
                    } else {
                        set a [::ripemd::hmac160 -hex -key "$secret_key $remote_addr" $params_base32]
                        return
                    }
                }

                default {
                    error "Unknown session signature algorithm!"
                }
            }
        }

        # Do nothing if cookie is not present
    }



    # Function: get_param
    #
    # It retrieves param stored in session. If param does not exist,
    # empty string is returned.
    #
    # Parameters:
    #   - Name of param
    method get_param {k} {
        variable params

        if {[dict exists $params $k]} {
            return [dict get $params $k]
        }

        return
    }

    # Function: set_param
    #
    # It sets param and stores it in session.
    #
    # Parameters:
    #   - Name of param
    #   - Value of param
    method set_param {k v} {
        variable params
        dict set params $k $v
    }

    # Function: get_params
    #
    # It retrieves list of all params stored in session.
    #
    # Parameters:
    #   - Name of param
    method get_params {} {
        variable params
        return $params
    }

    # Function: set_params
    #
    # It sets multiple params.
    #
    # Parameters:
    #
    #   - Dict containing param-value pairs
    method set_params {p} {
        variable params
        set params [dict merge $params $p]
    }

    method output__ {request interface_out} {
        variable params
        variable secret_key
        variable config

        set output {}
        set params_base32 [::base32::encode $params]
        set params_signature {}
        set remote_addr [$request get_header REMOTE_ADDR]

        # Sign cookie, note that we're using HMAC for signatures
        switch [dict get $config app session algorithm] {
            sha256 {
                package require sha2

                set params_signature [::sha2::hmac -hex -key "$secret_key $remote_addr" $params_base32]
            }

            ripemd160 {
                package require ripemd160

                set params_signature [::ripemd::hmac160 -hex -key "$secret_key $remote_addr" $params_base32]
            }

            default {
                error "Unknown session signature algorithm!"
            }
        }

        # Replace all "=" with "-". It is needed to make cookies work properly
        regsub -all -- {=} $params_base32 {-} params_base32

        # Generate cookie body
        dict set output b32 $params_base32
        dict set output s $params_signature

        # Calculate expiration date
        set expiration_seconds [+ [clock seconds] [dict get $config app session seconds]]

        # Feed browser with tasty cookie ;)
        $interface_out set_cookie [dict get $config app session cookie_name] $output $expiration_seconds
    }
}