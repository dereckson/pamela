#!/usr/bin/env tclsh8.5
#
# Gets MAC addresses
#
# If this code is copyright eligible,
# (c) 2010 Sébastien Santoro aka Dereckson
# All rights reserved. Released under BSD license.
#

#
# Config
#

#The database containing mac information
#You can so hide a MAC address you don't want to print
#or gives it a custon name.
set macs(db) /tmp/pamela.db

#Path to libtclsqlite.so, if it's needed to manually load it
set macs(libtclsqlite) "/usr/local/lib/sqlite/libtclsqlite.so"

#Resolves names?
set macs(resolvenames)  0

#If so, a list of domains to strip, to keep only machine name
set macs(domains_to_strip) {
    .dereckson.be
    .wolfplex.org
}

#Before call arp, do you want to launch a command?
#The goal is to fill up our arp cache.
set macs(pre-arp) "nmap -sn 10.0.0.0/24"

#
# Helper methods
#

proc clean_name {name} {
    global macs
    if {[llength $macs(domains_to_strip)] > 0} {
        set map {}
        foreach domain $macs(domains_to_strip) {
            lappend map $domain
            lappend map {}
        }
        set name [string map $map $name]
    }
    return $name
}

proc get_entry {mac name} {
    global macs

    #Query database
    if {[info exists macs(knownmacs)]} {
        foreach "row_userid row_mac row_name" $macs(knownmacs) {
            if {$row_mac == $mac} {
                return $row_name
            }
        }
        #TODO: if macs is to be filled with all macs, it's here
    }

    #Returns resolved name    
    if {$macs(resolvenames) && $name != "?"} {
        return [clean_name $name]
    }

    #Returns MAC address
    return $mac
}

proc get_macs {} {
    global macs
    set entries {}
    if $macs(resolvenames) {
        set arp_data [exec arp -a]
    } {
        set arp_data [exec arp -a -n]
    }
    foreach line [split $arp_data \n] {
        set name [lindex $line 0]
        set MAC [lindex $line 3]
        if {$MAC != "(incomplete)"} {
            set entry [get_entry $MAC $name]
            if {$entry != ""} {
                lappend entries $entry
            }
        }
    }
    return $entries
}

proc json_encode_array {list} {
    #["openwrt", "HSB-AP-ch4", "f4:0c:69:e6:50:63"]
    set json "\[\""
    append json [join $list "\", \""]
    append json "\"\]"
}

#
# Procedural code
#

#Executes the preload command
catch {exec {*}$macs(pre-arp)}

#Loads database information
if {[info exists macs(db)] && $macs(db) != ""} {
    if {[info exists macs(libtclsqlite)] && $macs(libtclsqlite) != ""} {
        load $macs(libtclsqlite)
    } {
        package require sqlite
    }
    sqlite db $macs(db)
    set macs(knownmacs) [db eval {SELECT * FROM knownmacs}]
    db close
}

#MAC output
puts [json_encode_array [get_macs]]