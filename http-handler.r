Rebol [
	file: %http-handler.r
	title: "Http handler and support functions"
	author: "Graham Chiu"
	date: 8-Feb-2017
]

user-rule: charset [ #"a" - #"z" #"A" - #"Z" #"0" - #"9"]
digits: charset [ #"0" - #"9"]

; send a http response
send-page: func [http-port code data mime /local len tmp] [
    print "calling send-page"
    len: length? data
    tmp: rejoin [
        "HTTP/1.0 " code " OK^/"
        "Date:" to-http-date "^/"
        "Server: Rebol " rebol/version "^/"
        "Content-type: " mime "^/"
        "Content-Length: " len "^/^/"
        data
    ]
    write-io http-port tmp length? tmp
]

if not exists? join web-root description [
    ; get the blank description for sssdp device
    xml: read description-xml
    ; now customize it before saving it
    foreach [orig custom] reduce [
        "(local-ip)" rejoin ["(" local-ip ")"]
        {<serialNumber>(null)</serialNumber>} rejoin [{<serialNumber>} hue-config/bridge-id </serialNumber>]
        {<URLBase>(none)</URLBase>}  rejoin [{<URLBase>} "http://" local-ip ":" web-portno "/" </URLBase>]
        {<UDN>(none)</UDN>} rejoin [{<UDN>uuid:} hue-config/uuid </UDN>]
    ][ replace xml orig custom]
    write join web-root description trim/head/tail xml
]

space: #" "

unauthorized: func [http-port][
    send-page 401 "Not authorized" "text/text;"
]

api-error: func [ no req text
    /local errobj errors
][
    errors: copy []
    errobj: make object! [
        error: make object! [
            type: to string! no
            address: req
            description: text
        ]
    ]
    append errors errobj
    replace/all to-json errors "\/" "/"
]

comment { sample command from Echo
PUT /api/username/lights/4/state HTTP/1.1
Host: 192.168.1.7:8000
Accept: */*
Content-type: application/x-www-form-urlencoded
Content-Length: 12

{"on": true}
}

GET-object: make object! [
    lights: make object! [
        default: func [http-port][send-page http-port 200 to-json bulbs "application/json;"]
        ^3: func [http-port][send-page http-port 200 to-json bulbs/^3 "application/json;"]
        ^4: func [http-port][send-page http-port 200 to-json bulbs/^4 "application/json;"]
    ]
]

object-dispatch: func [ object api-req 
    /local paths
][
    paths: exclude parse/all api-req "/" [""]
    until [
        object: get in object to word! paths/1
        paths: next paths
        tail? paths
    ]
    :object
]

; test: object-dispatch get-object "/lights/^^4"

; we are only going to support turning lights on and off
put-object: make object! [
    lights: make object! [
        default: func [http-port][send-page http-port 500 "Not supported" "text/text"]
        ^3: make object! [ 
            state: func [http-port payload
                /local tmp
            ][
                tmp: load-json payload
                ; need to check it is "on" object
                either tmp/on [
                    bulbs/^3/state/on: true 
                    send-page http-port 200 {[{"success":{"/lights/3/state/on":true}}]} "application/json;"
                    toggle-limitless zone2-on
                ][
                    bulbs/^3/state/on: false
                    send-page http-port 200 {[{"success":{"/lights/3/state/on":false}}]} "application/json;"
                    toggle-limitless zone2-off
                ]

                print ["payload is " payload]
            ]
        ]
        ^4: make object! [
            state: func [http-port payload
                /local tmp
            ][
                tmp: load-json payload
                ; need to check it is "on" object
                either tmp/on [
                    send-page http-port 200 {[{"success":{"/lights/4/state/on":true}}]} "application/json;"
                    ; do the actual light turning on here
                    toggle-limitless zone2-on
                ][
                    send-page http-port 200 {[{"success":{"/lights/4/state/on":false}}]} "application/json;"
                    ; do the actual light switching here
                    toggle-limitless zone2-off
                ]

                print ["payload is " payload]
            ]
        ]
    ]
]

; web buffer to store http requests
buffer: make string! 1024 

~digits: complement digits

crlfcrlf: join crlf crlf

http-handler: func [port
	/local http-port verb header body headers buffer2
][

    log "http Connection received ...."
    http-port: first port

    ; short-hands to use the http-port
    sendp: func [code data mime][
        print "using sendp"
        send-page http-port code data mime
    ]

    clear buffer
    if error? set/any 'err try [ ;'
        read-io http-port buffer 16380
        headers: header2object buffer make object! [Host: Authorization: Content-Type: Date: none Content-Length: 0]
    ][
        probe disarm err
    ] ;
    log rejoin ["HTTP Message from " http-port/remote-ip " on " http-port/remote-port newline] 
    log buffer
    either find buffer join "GET /" description [
    	log "sending description file"
        sendp 200 trim/head/tail read join web-root description "application/xml;"
    ][
        print "checking api call"
        either parse/all buffer [copy verb to space space copy request to space any space "HTTP/1." ["0"|"1"] 
            (print "thru http")
            thru crlf copy header to crlfcrlf crlfcrlf copy body to end]
        [

            ;; check for API call
            api-request: none
            parse/all request [ "/api/" copy username some user-rule [ "/" end | "/" copy api-request to end]]
            if api-request [
                parse/all api-request [some ~digits mark: copy light some digits (light: load light if light < 1000 [insert mark "^^"])]
            ]

            switch/default verb [
                "GET" [
                    either all [
                        none? api-request
                        username
                    ][
                        send-page http-port 200 return-json-config hue "application/json;"
                    ][
                        test: object-dispatch get-object api-request
                        case [
                            object? :test [
                                test/default http-port ;200 "application/json;"
                            ]
                            function? :test [
                                test http-port ;200 "application/json;"
                            ]
                            true [send-page http-port 500 "Unsupported operation" "text/text"]
                        ]
                    ]
                ]
                "POST" [
                    ; not implemented yet
                ]
                "PUT" [
                    either all [
                        username
                        not none? api-request
                        not none? body
                        string? api-request
                    ][
                        test: object-dispatch PUT-object api-request
                        either function? :test [
                            test http-port body
                        ][
                            send-page http-port 500 "Unsupported operation" "text/text"
                        ]
                    ][
                        send-page http-port 500 "Unsupported operation" "text/text"
                    ]
                ]
                "DELETE" [
                    ; delete-handler request headers body
                ]
            ][
                sendp 500 "Unrecognised http request" "text/text"
            ]
        ][
            sendp 500 "Unrecognised http request" "text/text"
        ]
    ]
    close http-port
    print "http-port closed"
    print buffer
]
