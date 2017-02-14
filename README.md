# Rebol-Hue-Bridge
A server written in Rebol to act as a minimal Philips Hue Bridge, and as an IFTTT target when using Amazon Echo.  The lights are actually
LimitlessLED bulbs controlled by a WiFi RF bridge but you can use any device that you can communicate with.

LimitlessLED bulbs are also known as MiLight and Easybulbs in other places where they are sold.

This is very much alpha code which works so far, but all the configurations are hand written.

As it is the Rebol Hue Bridge is detected by Amazon Echo Dot and any devices so configured are recognized enough that commands such as 

Alexa turn laundry on/off
Alexa turn bathroom lights on/off

are detected and the appropriate network commands are sent to my LimitlessLED bridge.
