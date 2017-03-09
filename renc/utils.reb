Rebol [
	file: %utils.reb
	title: "Hue config functions"
	author: "Graham Chiu"
	date: 8-Feb-2017
]

; easy web generator
get-uuid: does [
    attempt [
       page: read https://www.uuidgenerator.net/version4
       either parse page [ thru {<p class="info">Your Version 4 UUID:</p>} thru {<h2 class="uuid">} copy uuid to </h2> to end][
            return uuid
       ][
            return "no-uuid-available"
       ]
    ]
]


; Brian Otto
; http://codereview.stackexchange.com/questions/142544/a-version-4-uuid-implementation

makeUUID: func [
    "Generates a Version 4 UUID that is compliant with RFC 4122"
    /local data
][
    ; generate 16 random integers

    ; Note: REBOL doesn't support bytes directly 
    ; and so instead we pick numbers within the
    ; unsigned, 8-bit, byte range (0 - 255)

    ; Also random normally begins the range at 1, 
    ; not 0, and so -1/256 allows 0 to be picked
    data: collect [loop 16 [keep -1 + random/secure 256]]

    ; set the first character in the 7th "byte" to always be 4
    data/7: OR~ AND~ data/7 15 64

    ; set the first character in the 9th "byte" to always be 8, 9, A or B
    data/9: OR~ AND~ data/9 63 128

    ; convert the integers to hexadecimal
    data: enbase/base to binary! data 16

    ; add the hyphens between each block 
    data: insert skip data 8 "-"
    data: insert skip data 4 "-"
    data: insert skip data 4 "-"
    data: insert skip data 4 "-"

    head data
]

now-gmt: func [ /local t][
        t: now
        t: t - t/zone
        t/zone: _
        t
    ]

; returns the current date and time for web server use
to-http-date: func [
    /local d
] [
    d: now-gmt
    rejoin [
        copy/part pick system/locale/days d/weekday 3
        ", " next form 100 + d/day " "
        copy/part pick system/locale/months d/month 3
        " " d/year " "
        next form 100:00 + d/time " +0000"
    ]
]

format-10: func [d [integer! decimal!]] 
[
    next form 100 + d
]

; takes a date and formats as ISO8601 for use in JSON
to-ISO8601-date: func [d [date!]] 
[
    ajoin [
        d/year "-"
        format-10 d/month "-"
        format-10 d/day "T"
        format-10 d/time/1 ":"
        format-10 d/time/2 ":"
        format-10 round d/time/3 ; round/to d/time/3 .1 "00Z"
    ]
]
