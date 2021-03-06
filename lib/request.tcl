# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Request
#
# It contains informations about the request, like headers, params, etc. You shouldn't
# construct it.
oo::class create ::Achatina::Request {
    constructor {interface_in_} {
        variable headers {}
        variable params {}
        variable placeholders {}
        variable all_params {}
        variable params_without_meta {}
        variable interface_in $interface_in_

        set headers [$interface_in get_headers]
        set params [$interface_in get_params]

        if {![dict exists $headers HTTP_HOST]} {
            error "HTTP_HOST is not present (is client not using HTTP/1.1?)"
        }

        if {![dict exists $headers PATH_INFO]} {
            error "PATH_INFO is not present"
        }

        if {![dict exists $headers REQUEST_METHOD]} {
            error "REQUEST_METHOD is not present"
        }

        if {![dict exists $headers SCRIPT_NAME]} {
            error "SCRIPT_NAME is not present"
        }

        if {![dict exists $headers REMOTE_ADDR]} {
            error "REMOTE_ADDR is not present"
        }

        dict set headers __URL_BASE__ [my normalize_url "[dict get $headers __PROTOCOL__]://[dict get $headers HTTP_HOST]/[dict get $headers SCRIPT_NAME]/"]
        dict set headers __URL_REAL_BASE__ [my normalize_url "[dict get $headers __PROTOCOL__]://[dict get $headers HTTP_HOST]/"]
    }

    method normalize_url {u} {
        if {[regexp {([a-zA-Z]+://)(.+)} $u {} protocol address]} {
            regsub -all {/+} $address {/} address
            return $protocol$address
        }

        return [regsub -all {/+} $u {/}]
    }

    method _join_params {} {
        variable all_params
        variable params
        variable placeholders

        set all_params [dict merge $params $placeholders]
    }

    method _gen_params_dict_without_meta {} {
        variable all_params
        variable params_without_meta

        # Check whether all params are cached, if not, generate dict with them
        if {$all_params eq ""} {my _join_params}

        dict for {k v} $all_params {
            # We only use first value, for sake of simplicity
            set first_value [lindex $v 0]
            if {[dict exists $first_value value]} {
                dict set params_without_meta $k [dict get $first_value value]
            }
        }
    }

    # Function: get_header
    #
    # It returns specified header value. If header does not exist
    # it returns empty string. You can rely on existence of following headers:
    #
    # > REMOTE_ADDR
    # > REQUEST_METHOD
    # > __PROTOCOL__
    # > SCRIPT_NAME
    # > __URL_BASE__
    # > __URL_REAL_BASE__ 
    # > HTTP_HOST
    #
    # Parameters:
    #
    #   - Name of header
    method get_header {h} {
        variable headers

        if {[dict exists $headers $h]} {
            return [dict get $headers $h]
        } else {
            return
        }
    }

    # Function: get_headers
    #
    # It returns dict of all headers.
    #
    # This method takes no arguments
    method get_headers {} {
        variable headers
        return $headers
    }

    # Function: get_param
    #
    # It returns value of specified (GET or POST or route placeholder) param.
    #
    # If param has more than one value, this method will return only first one.
    # For capturing more than one value, use <get_param_with_meta>.
    #
    # Usage:
    #
    # > get_param key
    #
    # Parameters:
    #   - key - Key of param
    method get_param {p} {
        variable params_without_meta

        # Check whether all params (without meta) are cached, if not, generate dict with them
        if {$params_without_meta eq ""} {my _gen_params_dict_without_meta}

        # Params from placeholders have priority
        if {[dict exists $params_without_meta $p]} {
            return [dict get $params_without_meta $p]
        }

        return
    }

    # Function: get_param_with_meta
    #
    # It returns value of specified (GET or POST or route placeholder) param with metadata. Metadata is in
    # same format as in ncgi.
    #
    # Usage:
    #
    # > get_param_with_meta key
    #
    # Parameters:
    #   - key - Key of param

    method get_param_with_meta {p} {
        variable all_params

        # Check whether all params are cached, if not, generate dict with them
        if {$all_params eq ""} {my _join_params}

        # Params from placeholders have priority
        if {[dict exists $all_params $p]} {
            return [dict get $all_params $p]
        }

        return
    }

    # Function: get_params
    #
    # It returns dict of all params.
    #
    # If param has more than one value, this method will return only first one.
    # For capturing more than one value, use <get_params_with_meta>.
    #
    # This method takes no arguments.
    method get_params {} {
        variable params_without_meta

        # Check whether all params (without meta) are cached, if not, generate dict with them
        if {$params_without_meta eq ""} {my _gen_params_dict_without_meta}

        return $params_without_meta
    }

    # Function: get_params_with_meta
    #
    # It returns dict of all params with metadata. Metadata is in same format
    # as in ncgi.
    #
    # This method takes no arguments.
    method get_params_with_meta {} {
        variable all_params

        # Check whether all params are cached, if not, generate dict with them
        if {$all_params eq ""} {my _join_params}

        return $all_params
    }

    method get_interface_in__ {} {
        variable interface_in
        return $interface_in
    }

    method set_placeholders__ {p} {
        variable placeholders {}

        dict for {k v} $p {
            dict set placeholders $k [list [dict create value $v metadata {}]]
        }
    }
}