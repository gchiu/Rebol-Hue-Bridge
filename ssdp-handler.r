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
}

; given an object, it will parse the header to get the relevant fields.  
; First line of header includes verb
header2object: func [ message obj
	/local temp val members digits
][
	digits: charset [#"0" - #"9"]
	; lets get all the members of the object
	members: next first obj
	; now let us make a rule and parse out what we need.
	foreach member members [
		temp: rejoin [newline to string! member ":"]
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

make-search-obj: does [
	make object! [ host: man: mx: st: none]
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
	rejoin [
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
ssdp-handler: func [port
	/local message tmp device data err
][
    print "SSDP message"
    data: copy port
    ; log rejoin ["SSDP Message from " port/remote-ip " on " port/remote-port newline] 
    ; log data

	parse data [ copy tmp to newline (print tmp)]
    if find/part data {M-SEARCH} 8 [
    	log rejoin ["SSDP m-search Message from " port/remote-ip " on " port/remote-port newline] 
        log data

        ; see if the search is of type ssdp:all or urn:schemas-upnp-org:device:basic:1
        message: header2object data make-search-obj

        ?? message

        ; if port/remote-ip = 192.168.1.84 [halt]

        if any [
        	message/ST = "ssdp:all"
        	message/ST = "urn:schemas-upnp-org:device:basic:1"
        ][
        	; suppposed to wait 0.3 - 3 seconds before replying to avoid network flooding
            log "Connecting to Alexa hopefully"
            if error? set/any 'err try [
                device: open/binary rejoin [udp:// port/remote-ip ":" port/remote-port] ;'

                print ["Sending NOTIFY to " port/remote-ip " on " port/remote-port]

                ; should these be three separate sends?
                insert device create-notify-message rejoin [http:// local-ip ":" web-portno "/" description]
                	hue-config/bridge-id "upnp:rootdevice" rejoin [ {uuid:} hue-config/uuid {::upnp:rootdevice} ]

                insert device create-notify-message rejoin [http:// local-ip ":" web-portno "/" description]
                	hue-config/bridge-id rejoin [{uuid:} hue-config/uuid]  rejoin [{uuid:} hue-config/uuid]

                insert device create-notify-message rejoin [http:// local-ip ":" web-portno "/" description]
                	hue-config/bridge-id {urn:schemas-upnp-org:device:basic:1} rejoin [{uuid:} hue-config/uuid]
            ][
                probe disarm err
            ]
			attempt [close device]
        ]
    ]
    print now/precise
    ; probe data
]

;; ============================= samples ====================================

; response to rootdevice?
NOTIFY: rejoin [
    {HTTP/1.1 200 OK} crlf
    {HOST: 239.255.255.250:1900} crlf
    {CACHE-CONTROL: max-age=100} crlf
    {EXT:} crlf
    {LOCATION: http://} local-ip ":" web-portno {/description.xml} crlf
    {SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0} crlf
    {hue-bridgeid: } hue-config/bridge-id crlf
    {ST: upnp:rootdevice} crlf
    {USN: uuid:} hue-config/uuid {::upnp:rootdevice} crlf
    crlf
]

NOTIFY1: rejoin [
    {HTTP/1.0 200 OK} crlf
    {HOST: 239.255.255.250:1900} crlf
    {CACHE-CONTROL: max-age=100} crlf
    {EXT:} crlf
    {LOCATION: http://} local-ip ":" web-portno {/description.xml} crlf
    {SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0} crlf
    {hue-bridgeid: } hue-config/bridge-id crlf
    {ST: upnp:rootdevice} crlf
    {USN: uuid:} hue-config/uuid {::upnp:rootdevice} crlf
    crlf
]

NOTIFY2: rejoin [
    {HTTP/1.0 200 OK} crlf
    {HOST: 239.255.255.250:1900} crlf
    {CACHE-CONTROL: max-age=100} crlf
    {EXT:} crlf
    {LOCATION: http://} local-ip ":" web-portno {/description.xml} crlf
    {SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0} crlf
    {hue-bridgeid: } hue-config/bridge-id crlf
    {ST: uuid:} hue-config/uuid crlf
    {USN: uuid:} hue-config/uuid crlf
    crlf
]

NOTIFY3: rejoin [
    {HTTP/1.0 200 OK} crlf
    {HOST: 239.255.255.250:1900} crlf
    {CACHE-CONTROL: max-age=100} crlf
    {EXT:} crlf
    {LOCATION: http://} local-ip ":" web-portno {/description.xml} crlf
    {SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0} crlf
    {hue-bridgeid: } hue-config/bridge-id crlf
    {ST: urn:schemas-upnp-org:device:basic:1} crlf
    {USN: uuid:} hue-config/uuid  crlf
    crlf
]
