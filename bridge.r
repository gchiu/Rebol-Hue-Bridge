REBOL [ 
    Notes: {to listen for SSDP messages}   
    Author: {Graham Chiu}
    Date: 5-Feb-2017
    Version: 0.0.1
] 

; reset the random generator for creating the bridge-id
random/seed now/precise

; to prevent network flooding, wait a random period from 0.3 - 3 seconds before starting network activity
wait delay: ((random 2700) + 300) / 1000

print ["Delayed start for " delay " secs"]

;; config stuff

; use Olsen IDs https://en.wikipedia.org/wiki/Tz_database
timezone: "Pacific/Auckland"
description-xml: %description.xml ; https://s3.amazonaws.com/rebol-hue-bridge/description.xml

description: %description.xml
logfile: %bridge-log.txt    
log?: on
; default directory to serve web requests
web-root: %www/
; port to listen to web requests
web-portno: 8000

; limitlessled hub address
limitlessled-url: udp://192.168.1.124:8899

zone1-on: #{450055}
zone1-off: #{460055}

zone2-on: #{470055}
zone2-off: #{480055}

toggle-limitless: func [data [binary!]
    /local port
][
    port: open limitlessled-url
    insert port data
    close port
]

if not exists? web-root [
    make-dir web-root
]

local-ip: read join dns:// read dns:// 
    
print ["Local IP address is " local-ip] 

; Json support
do http://reb4.me/r/altjson

; uuid, date handling
do %utils.r

; set up the hue variables and calls to return json responses for http calls
do %hue.r

;do %lights.r
do %groups.r

bulbs: make object! [
    ^3: make object! [
        state: make object! [
            on: false
            bri: 0
            hue: 0
            sat: 0
            effect: "none"
            ct: 0
            alert: "none"
            reachable: true
        ]
        type: "Dimmable light"
        name: "Bathroom Lights"
        modelid: "LWB004"
        manufacturername: "Philips"
        uniqueid: "00:17:88:5E:D3:03-03"
        swversion: "66012040"
    ]
    ^4: make object! [
        state: make object! [
            on: false
            bri: 0
            hue: 0
            sat: 0
            effect: "none"
            ct: 0
            alert: "none"
            reachable: true
        ]
        type: "Dimmable light"
        name: "Laundry"
        modelid: "LWB004"
        manufacturername: "Philips"
        uniqueid: "00:17:88:5E:D3:03-03"
        swversion: "66012040"
    ]
]

; handle incoming http and ssdp messages
do %http-handler.r
do %ssdp-handler.r

log: func [d /local data][
    if all [
        log? 
        string? d
    ][
        data: copy d
        insert data join now/precise newline
        append data newline
        write/append logfile data 
    ]
]

attempt [delete logfile]    
attempt [close ssdp] 
attempt [close ssdp-multicast] 
attempt [close webport]

; open a connection to the SSDP multicast address
ssdp-multicast: open/binary udp://239.255.255.250:1900 ; SSDP multicast address and port 
set-modes ssdp-multicast [multicast-ttl: 10] 
set-modes ssdp-multicast compose/deep [multicast-interface: (local-ip)] 

; open a server connection to listen to SSDP messages we have subscribed to on the SSDP on port 1900
ssdp-portno: 1900
ssdp: open/binary join udp://: ssdp-portno 
set-modes ssdp compose/deep [multicast-groups: [[239.255.255.250 (local-ip)]]] 
    
; open a web server for messages from devices doing discovery
webport: open/lines join tcp://: web-portno

wait-ports: []
append wait-ports ssdp-multicast
append wait-ports ssdp
append wait-ports webport

; just to kick things off, something like this seems to be needed otherwise sometimes I do not see the SSDP messages

; insert ssdp-multicast M-SEARCH

forever [ 
    port: wait wait-ports

    probe port/port-id

    switch/default port/port-id reduce [
        ssdp-portno [
            ssdp-handler port
        ]
        web-portno [
            http-handler port
        ]
    ][  
        ; timeout if one is present
        print "SSDP response message"
    ]
]
