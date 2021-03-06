# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Ladies and gentlemen, I present you the ugliest templating engine ever!

# Class: ::Achatina::Template
#
# Achatina templating engine.
#
# Example:
#
# > method do_get {request session config} {
# >     set template [::Achatina::Template new aaa.xxx $config]
# >     $template set_param lol 123
# >     return [$template get_output]
# > }
#
# Example template file:
#
# > <: if {1} { :>
# >     <:= $lol :>
# > <: } :>
oo::class create ::Achatina::Template {
    # Constructor: new
    #
    # It construct template object and loads specified template file.
    #
    # Arguments to this method must form valid dictionary.
    #
    # Usage:
    #
    # > ::Achatina::Template new -filename filename -config config
    #
    # Parameters:
    #   - filename - Path to template file (either absolute or relative to app->template->path configuration setting)
    #   - config - <::Achatina::Configuration> object
    #
    # Example:
    # 
    # > set tmpl [::Achatina::Template new -filename a.xxx -config $config]
    constructor {args} {
        namespace path ::tcl::mathop

        variable path {}
        variable contents {}
        variable compiled {}
        variable output {}
        variable variables {}

        # Validate arguments
        if {[catch {set tmpl_file [dict get $args -filename]}]} {
            error "Invalid arguments to ::Achatina::Template constructor"
        }

        if {[catch {set config [dict get $args -config]}]} {
            error "Invalid arguments to ::Achatina::Template constructor"
        }

        set ext [$config get_param app template extension]
        set path [$config get_param app template path]

        if {([file pathtype $tmpl_file] eq "absolute") || ([file pathtype $tmpl_file] eq "volumerelative")} {
            set filename1 $tmpl_file
            set filename2 "$tmpl_file.$ext"
        } else {
            set filename1 [file normalize [file join [file dirname [file normalize $::argv0]] $path $tmpl_file]]
            set filename2 [file normalize [file join [file dirname [file normalize $::argv0]] $path "$tmpl_file.$ext"]]
        }

        try {
            set fp [open $filename1 r]
        } on error err {
            try {
                set fp [open $filename2 r]
            } on error err {
                error {Template not found}
            }
        }

        set contents [read $fp]
        close $fp
    }

    method _compile {} {
        variable contents
        variable variables
        variable compiled
        variable output

        set return_value ""
        set template $contents

        # Process params
        if {$variables ne ""} {
            dict for {name value} $variables {
                append return_value "set $name {$value}\n"
            }
        }

        while {[string length $template] != 0} {
            # At end of every iteration, processed part of supplied string is
            # deleted

            # Locate opening and ending tags
            set index [string first {<:} $template]
            set closing_index [string first {:>} $template]

            # Number of opening and ending tags must be equal
            if {($index != -1) && ($closing_index == -1)} {
                return {EXCPECTED: :&gt;}
            }

            if {($index == -1) && ($closing_index != -1)} {
                return {UNEXCPECTED: &lt;:}
            }

            # Now we have plain text, without any tags following
            if {$index == -1} {
                    append return_value "append output {[string range $template 0 end]}\n"
                    set template ""
            # Plain text followed by tags
            } elseif {$index != 0} {
                append return_value "append output {[string range $template 0 [- $index 1]]}\n"
                set template [string range $template $index end]
            # <%= tag
            } elseif {[string index $template [+ $index 2]] eq "="} {
                append return_value "append output [subst {[string trim [string range $template [+ $index 3] [- $closing_index 1]]]}]\n"
                set template [string range $template [+ $closing_index 2] end]
            # <% tag
            } else {
                append return_value "[string range $template [+ $index 3] [- $closing_index 1]]\n"
                set template [string range $template [+ $closing_index 2] end]
            }
        }
        set compiled $return_value
    }

    # Function: get_param
    #
    # It gets specified param from template object. Params are set by <set_param> and <set_params>.
    #
    # Usage:
    #
    # > get_param key
    # 
    # Parameters:
    #   - key - Key of requested param
    method get_param {k} {
        variable variables
        if {[dict exists $variables $k]} {
            return [dict get $variables $k
        }

        return
    }

    # Function: set_param
    #
    # It sets template param which will appear in template as variable with same name.
    #
    # Usage:
    #
    # > set_param key value
    #
    # Parameters:
    #   - key - Key of param
    #   - value - Value of param
    method set_param {k v} {
        variable variables
        dict set variables $k $v
    }

    # Function: set_params
    #
    # It sets multiple template params.
    #
    # Usage:
    #
    # > set_params dict
    #
    # Parameters:
    #   - dict - Dict containing multiple param-value pairs
    method set_params {p} {
        variable variables
        set variables [dict merge $variables $p]
    }

    # Function: get_output
    #
    # It returns string containing template output. Note that this
    # method does not return <::Achatina::Response> object.
    #
    # Usage:
    #
    # > get_output ?-force-recompile?
    #
    # Parameters:
    #
    #   - (optional) If you set first argument to "-force-recompile" then template will be recompiled (if it was already compiled).
    method get_output {{recompile -use-cached}} {
        variable compiled
        variable output

        if {($compiled eq "") || ($recompile eq "-force-recompile")} {
            my _compile
        }

        eval $compiled

        return $output
    }
}