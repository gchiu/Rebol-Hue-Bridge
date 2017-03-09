Rebol [
	file: %ssdp-handler.r
	title: "SSDP handler and support functions"
	author: "Graham Chiu"
	date: 8-Feb-2017
]

comment {
We only need to respond to basic device search like this one:

M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 15
ST: urn:schemas-upnp-org:device:basic:1
}

comment {
s: {M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 15
ST: urn:schemas-upnp-org:device:basic:1}
;}


; given an object, it will parse the header to get the relevant fields.  
; First line of header includes verb
header2object: func [ message obj
	/local temp val members digits
][
	digits: charset [#"0" - #"9"]
	; lets get all the members of the object
	; members: words-of obj
	; now let us make a rule and parse out what we need.
	foreach member words-of obj [
		temp: ajoin [newline to string! member ":"]
		parse message [thru temp [copy val to newline | copy val to end](
				trim/head/tail val
				if parse val [some digits][
					val: load val
				]
				obj/:member: val
			)
		]
	]
	obj
]
; o: header2object header s: make object! [Host: Authorization: Content-Type: Date: none Content-Length: 0]

; to test the functions
; r: header2object s make object! [ man: st: host: mx: none ]
; USER-AGENT: Google Chrome/56.0.2924.87 Windows

make-search-obj: does [
	make object! [ host: man: mx: st: USER-AGENT: _]
]

ST: "ssdp:all" 
MX: 3 

M-SEARCH: rejoin [ 
         {M-SEARCH * HTTP/1.1} crlf 
         {HOST: 239.255.255.250:1900} crlf 
         {MAN: "ssdp:discover"} crlf 
         {MX: } MX crlf 
         {ST: } ST crlf 
         crlf 
] 

create-notify-message: func [location bridge-id st usn][
	ajoin [
	    {HTTP/1.1 200 OK} crlf
	    {HOST: 239.255.255.250:1900} crlf
	    {CACHE-CONTROL: max-age=100} crlf
	    {EXT:} crlf
	    {LOCATION: } location crlf
	    {SERVER: Rebol UPnP/1.0 IpBridge/1.15.0} crlf
	    {hue-bridgeid: } bridge-id crlf
	    {ST: } st crlf
	    {USN: } usn crlf
	    crlf
	]
]

; we only need to respond to a M-SEARCH command.  Nothing else.
ssdp-handler: func [port datum
	/local message tmp err client data device delay
][
    client: query port
    print "Client structure:"
    probe client

    parse datum [ copy verb to space to end]
    print reform [ "SSDP"  verb "message received from" client/remote-ip]
    if equal? client/remote-ip local-ip [
        print "returning as is from local-ip"
        return false
    ]
    data: copy datum
    clear datum

	; parse data [ copy tmp to newline (print tmp)]
    if find/part data {M-SEARCH} 8 [
        message: header2object data make-search-obj
        print ajoin ["SSDP m-search Message from " client/remote-ip " on " client/remote-port newline] 

        ; see if the search is of type ssdp:all or urn:schemas-upnp-org:device:basic:1

        log data

        probe message

        if any [
        	message/ST = "ssdp:all"
        	message/ST = "urn:schemas-upnp-org:device:basic:1"
        ][
        	; suppposed to wait 0.3 - 3 seconds before replying to avoid network flooding
            log "Connecting to Alexa hopefully"

            ; need to wait if there's a MX value
            if all [
                in message 'MX
                integer? delay: message/MX
            ][
                probe message
                delay: min 5 delay

                delay: (random (100 * delay)) / 100 
                print ["Waiting " delay " seconds"]
                wait/only delay
            ]

; probe message halt

            print "=========================================================================================================="

            clear ssdp-buffer
            ssdp-block: copy []
            append ssdp-block create-notify-message rejoin [http:// local-ip ":" web-portno "/" description]
                    hue-config/bridge-id "upnp:rootdevice" ajoin [ {uuid:} hue-config/uuid {::upnp:rootdevice} ]
            append ssdp-block create-notify-message rejoin [http:// local-ip ":" web-portno "/" description]
                    hue-config/bridge-id rejoin [{uuid:} hue-config/uuid]  ajoin [{uuid:} hue-config/uuid]

            append ssdp-block create-notify-message rejoin [http:// local-ip ":" web-portno "/" description]
                    hue-config/bridge-id {urn:schemas-upnp-org:device:basic:1} ajoin [{uuid:} hue-config/uuid]
            ; filled the ssdp-buffer, and now ask the ssdp awake function to write it
            ; ssdp/awake make event! [type: 'write port: ssdp]   

            device: open rejoin [udp:// client/remote-ip ":" client/remote-port]
            device/awake: func [evt][ 
                print ["Event type on client UDP" evt/type]
                switch/default evt/type [ 
                    lookup [
                        print "writing to Alexa"
                        write %ssdp.bin ssdp-buffer
                        write evt/port to binary! take ssdp-block ; ssdp-buffer
                    ]
                    wrote [
                        ;clear ssdp-buffer
                        either not empty? ssdp-block [
                            write evt/port to binary! take ssdp-block
                        ][
                            close evt/port
                            return true
                        ]
                    ]
                    error [
                        ; do we need to exit on error?
                        return true
                    ]
                ][ return true]
                false
            ] 
            wait/only device
        ]
    ]
    print now/precise
    ; probe data
]
