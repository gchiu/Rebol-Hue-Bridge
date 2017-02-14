rebol [
	file: %groups.r
    title: "Groups of lights - default to lights 3 & 4"
]

groups: make object! [
    ^1: make object! [
        action: make object! [
            on: false
            bri: 0
            hue: 0
            sat: 0
            effect: "none"
            ct: 0
            alert: "none"
            reachable: true
        ]
        lights: [
            "3" 
            "4"
        ]
        name: "AGroup"
        type: "Room"
        class: "Other"
    ]
]