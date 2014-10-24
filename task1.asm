; Lab4, Task 1
; Take keypad input and then display it on the LCD

.include "m64def.inc"

.def tmp = r16
.def tmp2 = r17

; Used by the LCD
.def del_lo = r18
.def del_hi = r19
.def data = r25	; from keypad to LCD

; .equ PORTDDIR = 0xF0	; PD7-4: output, PD3-0, input
; .equ INITCOLMASK = 0xEF	; scan from leftmost col.
; .equ INITROWMASK = 0x01	; scan from top row
; .equ ROWMASK = 0x0F		; for getting input from Port D


.cseg
.org 0	;interrupt vector
	rjmp RESET

.include "keypad.asm"
.include "lcd.asm"


RESET:
	; Init. stack
	ldi tmp, low(RAMEND)
	out SPL, tmp
	ldi tmp, high(RAMEND)
	out SPH, tmp

	; Setup the keypad for input on PORTD
	ldi tmp, PORTDDIR	; PD[7-4]/PD[3-0], out/in
	out DDRD, tmp

	ser tmp
	; LCD ports for output
	out DDRB, tmp
	out DDRE, tmp

	; Debugging with LEDs
	out DDRA, tmp		; LEDs for debug PORTC
	; PORTA, tmp		; All on.

	;init_lcd	; Start up LCD
	
	clr data

MAIN:
	call SCAN_KEYPAD
	
	;lcd_write_data

	out PORTA, data		; debug LEDs
	call long_delay

	rjmp MAIN
