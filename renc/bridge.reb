REBOL [ 
    File: %bridge.reb
    Notes: {to act as a Hue bridge for amazon Echo}   
    Author: {Graham Chiu}
    Date: 5-Feb-2017
    Version: 0.0.1
    notes: {
        25-Feb-2017 port started to ren-c
        5-Mar-2017 working first version in ren-c
        9-Mar-2017 tidying up for first github posting

    }
] 

; reset the random generator for creating the bridge-id
random/seed now/precise

??: :dump

do %httpd.reb

; to prevent network flooding, wait a random period from 0.3 - 3 seconds before starting network activity
wait delay: ((random 2700) + 300) / 1000

print ["Delayed start for " delay " secs"]

dbug: func [no][
    print ["At line: " no " <enter>"]
    input
]

;; config stuff

; use Olsen IDs https://en.wikipedia.org/wiki/Tz_database
timezone: "Pacific/Auckland"
description-xml: https://s3.amazonaws.com/rebol-hue-bridge/description.xml

description: %description.xml
logfile: %bridge-log.txt    
log?: true
; default directory to serve web requests
web-root: %www/
; port to listen to web requests
web-portno: 80

; limitlessled hub address
limitlessled-url:  ; udp://192.168.1.124:8899 ; udp://192.168.1.102:8899 

if not exists? web-root [
    make-dir web-root
]

;; -- fix this --
local-ip: read dns://Graham-surface ; join dns:// read dns:// 
; local-ip: 0.0.0.0 ; INADDR_ANY
    
print ["Local IP address is " local-ip] 


; Json support
; do http://reb4.me/r/altjson
do https://gist.githubusercontent.com/rgchris/96a02d1a226d0ab2e605914fce6bcf80/raw/54300d0edf8b3aae30448ddea444050e78478d48/altjson-renc.reb
; do https://gist.githubusercontent.com/rgchris/96a02d1a226d0ab2e605914fce6bcf80/raw/f96b8a1b7bb9b9f972f86e45f8d74a404808b747/altjson-renc.reb

; uuid, date handling
do %utils.reb

; set up the hue variables and calls to return json responses for http calls
do %hue.reb

do %groups.r
; load all the bulbs/devices
do %devices.reb

; handle incoming http and ssdp messages
do %http-handler.reb
do %ssdp-handler.reb

log: func [d /local data temp][
    if all [
        log? 
        string? d
    ][
        write/append logfile temp: ajoin [now/precise newline d newline]
        print join-of "Log: " temp

    ]
]

attempt [delete logfile]    
attempt [close ssdp] 
attempt [close ssdp-multicast] 
attempt [close serve-http]

; open a connection to the SSDP multicast address
ssdp-multicast: open udp://239.255.255.250:1900 ; SSDP multicast address and port 

; open a server connection to listen to SSDP messages we have subscribed to on the SSDP on port 1900
ssdp-portno: 1900
ssdp: open rejoin [udp://: ssdp-portno] 

set-udp-multicast ssdp 239.255.255.250 local-ip ; 0.0.0.0 
set-udp-ttl ssdp 1

; device: open rejoin [udp:// client/remote-ip ":" client/remote-port]
ssdp-multicast/awake: func [evt][ 
    print ["Event type on ssdp-multicast UDP" evt/type]
    switch/default evt/type [ 
        lookup [
            write evt/port to binary! M-SEARCH
        ]
        wrote [
            ; clear ssdp-buffer
            ; close evt/port
            return false
        ]
        error [
            ; do we need to exit on error?
            return true
        ]
    ][ return true]
    false
] 

make-api-error: func [ no address description
    /local result
][
    result: to-json make object! compose/deep [ 
        error: make object! [ 
            type: (to string! no)
            address: (address)
            description: (description)
        ]
    ]
]

; command block [ binary! [ decimal! binary!]]
; send first binary.  If integer, wait decimal, then send second binary 
write-udp: func [url [url!] commands [block!]
    /local port command
][
    ; probe commands
    port: open url
    port/awake: func [evt][
        switch/default evt/type [
            print ["New event on limitlessled-url: " evt/type]
            lookup [ 
                print "doing write"
                write evt/port command: take commands
                false
            ]

            wrote [
                print ["sent " command]
                print "wrote now write again"
                if empty? commands [
                    print "no more data, closing port"
                    close evt/port
                    return true
                ]
                command: take commands
                if decimal? command [
                    print spaced ["sleeping" command "seconds"]
                    sleep command
                    command: take commands
                ]
                print ["writing " command]
                write evt/port command
                false
            ]

            read [
                data: read evt/port
                probe data
                false
            ]

            close [
                return true
            ]

            error [
                print "received unknown error"
                return true
            ]
        ][
            print "Unknown event"
            return true
        ]
    ]
    wait/only port
]


bits-on: #{41}
bits-off: #{42}
end-bits: #{0055}

turn-bulb-on-cmd: func [ {creates 3 byte sequence to toggle bulb based on group-no}
    state [logic!] group [integer!]
    /local result
][
    append add copy either state [bits-on][bits-off] 2 * group end-bits
]

comment {
    LIMITLESSLED RGBW COLOR SETTING is by a 3BYTE COMMAND: (First send the Group ON for the group you want to set the colour for. You send the group ON command 100ms before sending the 40)
Byte1: 0x40 (decimal: 64)
Byte2: 0x00 to 0xFF (255 colors) See Color Matrix Chart for the different values below.
Byte3: Always 0x55 (decimal: 85)

0x00 Violet
    0x10 Royal_Blue
    0x20 Baby_Blue
    0x30 Aqua
    0x40 Mint
    0x50 Seafoam_Green
    0x60 Green
    0x70 Lime_Green
    0x80 Yellow
    0x90 Yellow_Orange
    0xA0 Orange
    0xB0 Red
    0xC0 Pink
    0xD0 Fusia
    0xE0 Lilac
    0xF0 Lavendar
}

; takes a number 0-100 and coverts to hex value between 0x02 - 0x1B
mp2h: map-percent-to-hex: func [ percent [integer!]
    /local dec bin
][
    ; allowed range is 0x02 - 0x1B
    dec: 2 + to integer! 25 * percent / 100
    bin: append copy "#{" form remove/part form to-hex dec 15
    append bin "}"
    load bin
]

serve-http: open [
    Scheme: 'httpd
    Port-ID: :web-portno
    Awake: func [
        request [object!]
        /local body mime api-request api-path bulb-no device command commands result
    ][
        mime: "text/html"
        print ["http request at " now/precise]
        ; process all http events here, eg.
        probe request
        api-request: _

        switch request/action [
            "PUT" [set [mime body] put-handler request]
            "GET" [set [mime body] get-handler request]
            "DELETE" [] ; not defined yet
            "POST" [] ; not defined yet
        ]

        replace/all body {\/} {/}

        make object! compose [
            Status: 200
            Type: (mime)
            Content: (body)
        ]
    ]
]


wait-ports: copy []
append wait-ports ssdp-multicast
append wait-ports ssdp

attempt [browse rejoin [http://127.0.0.1 ":" web-portno "/description.xml"]]

; needed to tell Rebol which way the half duplex port is to start
read ssdp

ssdp-buffer: copy ""
ssdp/awake: func [evt][ 
    ; print ["multicast event:" evt/type " on " evt/port/spec/port-id " at " now/precise]
    ; probe query evt/port
    print ["Event received on UDP ===>" evt/type]

    switch/default evt/type [ 
        read [ 
            print ["read server data:" newline to-string evt/port/data] 
            ; process UDP notifications here
            append ssdp-buffer to string! copy evt/port/data
            if find evt/port/data crlf2bin [
                print "Calling ssdp handler here"
                ssdp-handler evt/port ssdp-buffer               
                clear evt/port/data 
                ; keep reading the port and not exit the awake function
                read evt/port
            ]
            false
            ; return true 
        ]
        write [
            ; we're going to send a write event to the awake handler.  We will look for data on the ssdp-buffer and use that

            log "writing back to SSDP client"
            ; write %ssdp.bin ssdp-buffer
            write evt/port to binary! ssdp-buffer
            false
        ]
        wrote [
            clear ssdp-buffer
            false
        ]
        error [
            ; do we need to exit on error?
            return true
        ]
    ][ return true]
    false
] 

print "Listening ..."
; read serve-udp ; seems to be necessary
forever [
    print ["start wait at " now/precise]
    wait wait-ports
]
