;Keypad Defs
.def row =r26
.def col =r27
.def mask =r21
.def temp2 =r20
;Globals Defs
.def input =r28
.def keypadCount = r30

; Constants
.equ PORTDDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

; Port mapping
.equ KP_DDR = DDRA
.equ KP_PORT = PORTA
.equ KP_PIN = PINA
