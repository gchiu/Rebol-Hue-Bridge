rebol [
	title: "Hue functions"
	file: %hue.r
	author: "Graham Chiu"
	date: 8-Feb-2017
]

hue-config: blank-config: make object! [
    bridge-id: _
    uuid: _
    users: []
]

if exists? %hue-config.reb [
    hue-config: load %hue-config.reb
    if error? try [
        hue-config/bridge-id
        hue-config/uuid
    ][
        delete %hue-config.reb
        hue-config: blank-config
    ]
]

if blank? hue-config/uuid [
    hue-config/uuid: makeUUID
]

if blank? hue-config/bridge-id [
    hue-config/bridge-id: random/secure 10000000
]

save/all %hue-config.r hue-config

;; set up the rebol object to respond to api calls with a Json object
hue: make object! [
    lights: scenes: groups: schedules: sensors: rules: config: _
]

make-blanko: does [
    make object! []
]
hue/scenes: make-blanko
hue/schedules: make-blanko
hue/rules: make-blanko
hue/lights: make-blanko
hue/groups: make-blanko

hue/config: config: make object! [
    portalservices: false
    gateway: "192.168.1.2"
    mac: "00:23:54:11:D4:52"
    swversion: "01036659"
    apiversion: "1.15.0"
    linkbutton: true
    ipaddress: "192.168.1.2"
    proxyport: 0
    swupdate: make object! [
        updatestate: 0
        checkforupdate: false
        devicetypes: make object! [
        ]
        text: ""
        notify: false
        url: ""
    ]
    netmask: "255.255.255.0"
    name: "Philips hue"
    dhcp: true
    UTC: "2017-02-05T22:51:34"
    proxyaddress: "none"
    localtime: "2017-02-06T11:51:34"
    timezone: "Antarctica/McMurdo"
    zigbeechannel: "6"
    modelid: "BSB002"
    bridgeid: "002354FFFE11D452"
    factorynew: false
    whitelist: make object! [
        test: make object! [
            lastUseDate: "2017-01-29T13:08:53"
            createDate: "2017-01-29T13:08:53"
            name: "auto insert user"
        ]
        newdeveloper: make object! [
            lastUseDate: "2017-02-06T11:41:03"
            createDate: "2017-02-06T11:41:03"
            name: "auto insert user"
        ]
    ]
]

update-hue-config: func [hue [object!]
	/local config
][
	config: hue/config
	config/gateway: local-ip
	config/ipaddress: local-ip
	config/timezone: timezone
	config/UTC: to-ISO8601-date now-gmt
	config/localtime: to-ISO8601-date now
	config/bridgeid: hue-config/bridge-id
	hue
]

; update the hue object and convert to Json
return-json-config: func [hue][
    update-hue-config hue
    hue/lights: bulbs
    hue/groups: groups
    to-json hue
]
