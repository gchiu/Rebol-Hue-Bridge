Rebol [
	file: %http-handler.reb
	title: "Http handler and support functions"
	author: "Graham Chiu"
	date: 8-Feb-2017
]

user-rule: charset [ #"a" - #"z" #"A" - #"Z" #"0" - #"9"]
digits: charset [ #"0" - #"9"]

~digits: complement digits

crlfcrlf: join-of crlf crlf

if not exists? join-of web-root description [
    ; get the blank description for sssdp device
    xml: to string! read description-xml
    ; now customize it before saving it 
    for-each [orig custom] reduce [
        "(local-ip)" rejoin ["(" local-ip ")"]
        {<serialNumber>(null)</serialNumber>} rejoin [{<serialNumber>} hue-config/bridge-id </serialNumber>]
        {<URLBase>(none)</URLBase>}  rejoin [{<URLBase>} "http://" local-ip ":" web-portno "/" </URLBase>]
        {<UDN>(none)</UDN>} rejoin [{<UDN>uuid:} hue-config/uuid </UDN>]
    ][ 
        replace xml orig custom
        dump orig
        dump custom
    ]
    trim/head/tail xml
    write rejoin [web-root description] xml
]

put-handler: function [request [object!]][
    commands: copy []
    mime: "application/json"

    ; PUT /api/.../lights/4/state HTTP/1.1
    ; /api/<username>/lights/<id>
    ; /api/<username>/lights/<id>/state
    parse request/target ["/api/" copy username some user-rule "/" copy device to "/" "/" copy bulb-no some digits "/" copy command to end]
    case [
        command = "state" [
            json: load-json request/payload
            print "JSON from Echo"
            probe json
            ;  make map! [ on true ]
            ; [{"success":{"/lights/1/name":"Bedroom Light"}}]
            ; bulbs/^3/name
            ; bulbs/^3/state/on
            ; make map! [
            ;    hue 50000
            ;    on true
            ;    bri 200
            ; ]
            ; success: {[{"success":{"/lights/$a/$b":"$c"}}]}
            ; "/lights/2/name"
            success: make map! []
            state-response: copy []
            case/all [
                find json 'on [
                    ; switching light on or off
                    if bulb: in bulbs to word! join-of "^^" bulb-no [
                        bulb: get bulb
                        switch bulb/manufacturername [
                            "Rebol" [
                                do bulb/script
                                append state-response success  
                            ]
                            "Philips" [
                                append state-response success  
                                append commands turn-bulb-on-cmd json/on to integer! bulb-no 

                            ]
                        ]


                        bulb/state/on: json/on
                        success: make map! []
                        success/success: make map! compose [
                            (lock unspaced [device "/" bulb-no "/state/on"]) (json/on)
                        ]
                    ]
                ]

                find json 'bri [
                    if bulb: in bulbs to word! join-of "^^" bulb-no [
                        bulb: get bulb
                        bulb/state/bri: json/bri
                        success: make map! []
                        success/success: make map! compose [
                            (lock unspaced [device "/" bulb-no "/state/bri"]) (json/bri)
                        ]
                        append state-response success  
                        if empty? commands [
                            ; if there's a brightness command and no on, we need to add an on command
                            append commands turn-bulb-on-cmd true to integer! bulb-no 
                        ]
                        append commands 0.1
                        ; convert brightness to a percentage of 0-255
                        intensity: to integer! (json/bri / 255 * 100) 
                        intensity: rejoin [#{4E} map-percent-to-hex intensity #{55}] 
                        append commands intensity
                    ]
                ]
            ]
            if not empty? commands [
                result: write-udp limitlessled-url commands
                print "completed sending bulb udp commands"
                probe :result
            ]

            probe state-response
            body: to-json state-response
        ]
        true [
            body: make-api-error "4" request/target "Method not implemented yet"
        ]
    ]
    return reduce [mime body]
]

get-handler: function [request [object!]]
[
    mime: "application/json"
    case [
        request/target = "/api/nouser/config" [
            body: {{"error":{"address":"/","description":"unauthorized user","type":"1"}}}
            mime: "application/json"
        ]
        request/target = "/description.xml" [
            body: trim/head/tail to string! read rejoin [web-root description]
            mime: "application/xml"
        ]

        parse request/target ["/api/" copy username some user-rule [
            end (
                ; /api/username
                ; return-json-config hue "application/json;"

                print "API request with no endpoint"
                ; mime: "application/json;"
                body: return-json-config hue

            )
            |
            "/" copy api-request to end (
                ; eg:   lights
                ;       lights/3
                ;       lights/new
                ; mime: "application/json;"
                print [ "API request:" api-request ]
                api-path: split api-request "/"
                case [
                    api-path/1 = "lights" [
                        if blank? api-path/2 [
                            ; /api/username/lights
                            body: to-json bulbs
                            replace/all body "^^" ""
                        ]
                        if all [
                            api-path/2
                            parse bulb-no: api-path/2 [some digits]
                        ][
                            either r: in bulbs to word! join-of "^^" bulb-no [
                                body: to-json get r
                            ][
                                body: make-api-error "3" request/target "Object Not Found"
                            ]
                        ]
                    ]
                    true [
                        ; api not implemented
                        body: make-api-error "4" request/target "Method not implemented yet"
                    ]
                ]
            )
        ]][]

        ; GET /api/M0CzaTFkQWn284908SmcTedeS3l7gBTZjscBMl3c HTTP/1.1

        true [
            mime: "text/html"
            body: reword "<h1>OK! $action :: $target</h1>" compose [
                action (request/action)
                target (request/target)
            ]
        ]
    ]
    return reduce [mime body]
]
