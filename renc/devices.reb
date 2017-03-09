Rebol [
	file: %devices.reb
	date: 9-Mar-2017
	author: "Graham Chiu"
	notes: {
		this file describes the "bulbs" or devices that you are going to use with the Rebol Hue Bridge
		You of course need to setup your own
	}
]

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
        name: "Monochrome"
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
        name: "Colors"
        modelid: "LWB004"
        manufacturername: "Philips"
        uniqueid: "00:17:88:5E:D3:03-03"
        swversion: "66012040"
    ]
    ^5: make object! [
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
        name: "Travis"
        modelid: "LWB004"
        manufacturername: "Rebol"
        uniqueid: "00:17:88:5E:D3:03-03"
        swversion: "66012040"
        script: [
            call/shell "update-aws.cmd"
            browse http://metaeducation.s3.amazonaws.com/index.html
        ]
    ]
    ^6: make object! [
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
        name: "stack chat"
        modelid: "LWB004"
        manufacturername: "Rebol"
        uniqueid: "00:17:88:5E:D3:03-03"
        swversion: "66012040"
        script: [
            browse http://chat.stackoverflow.com/rooms/291/rebol-and-red
        ]
    ]
]
