#!/usr/bin/env tclsh
source rnotifyd.conf

set iconname "weechat"
set timeout 10500
set sound ""
set canberra ""

if {[info exists rnotifyd-sound]} {
 set sound $::rnotifyd-sound
} elseif {[llength $::argv] > 0} {
 set sound [lindex $::argv 0]
}

if {[info exists rnotifyd-canberra] && [info exists rnotifyd-sound]} {
 set canberra [format "|%s" [format $::rnotifyd-canberra $::sound]]
} elseif {$sound != ""} {
 set canberra [format "|%s" [format "|ffmpeg -i %s -f pulse default -loglevel error" $sound]]
}


if {[info exists rnotifyd-iconname]} {
 set iconname $::rnotifyd-iconname
}

if {[info exists rnotifyd-expiry]} {
 set timeout $::rnotifyd-expiry
}

if {[info exists rnotifyd-bindaddr]} {
 set bindaddr $rnotifyd-bindaddr
} else {
 set bindaddr 127.0.0.1
}


if {[info exists rnotifyd-port]} {
 set port $rnotifyd-port
} else {
 set port 51001
}

source notifyc.tcl

package require libnotify

set procsock ""

proc rn:rd {sock} {
  global procsock
  gets $sock comd
  set argv [split $comd " "]
  if {[string tolower [lindex $argv 0]] == "q"} {
   close $sock
   return
  }
  if {[string tolower [lindex $argv 0]] == "b"} {
   notify send [binary decode base64 [lindex $argv 1]] [binary decode base64 [lindex $argv 2]] $::iconname $::timeout
   if {$::canberra != ""} {
    if {$procsock == ""} {
     set procsock [open "|ffmpeg -i $::sound -f oss /dev/dsp -loglevel error" r]; fileevent $procsock readable [list rn:closeprocess $procsock]
     return
    }
    if {[eof $procsock]} {
     set procsock [open "|ffmpeg -i $::sound -f oss /dev/dsp -loglevel error" r]; fileevent $procsock readable [list rn:closeprocess $procsock]
     return
    }
    return
   }
   return
  }
}

proc rn:closeprocess {proc} {
 global procsock
 close $proc
 set procsock ""
}

proc rn:accept {s a p} {
  chan configure $s -encoding utf-8 -buffering line
  chan event $s readable [list rn:rd $s]
}

socket -server rn:accept -myaddr $bindaddr $port

vwait never
