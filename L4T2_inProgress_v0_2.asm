/*
	Lab 4, Task 2
	Using Timer0 to do the count down till 1 second.
	Using an external interrupt to count motor revolutions 
		with the emitter detector.
*/
.include "m64def.inc"


.def tmp = r16
.def leds = r17
.def secondToggle = r18

; Clear a word in memory
; param @0 = mem. addr. to clear
.MACRO Clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr tmp
	st y+, tmp
	st y, tmp
.ENDMACRO

; Load data memory address into reisters
; param @0 = lower reg.
;		@1 = higher reg.
;		@2 = memory address
.MACRO LoadFromDataMem
	ldi YL, low(@2)
	ldi YH,	high(@2)
	ld @0, Y+
	ld @1, Y
.ENDMACRO

; Load program memory address into reisters
; param @0 = lower reg.
;		@1 = higher reg.
;		@2 = memory address
.MACRO LoadFromProgMem
	ldi ZL, low(@2)
	ldi ZH, high(@2)
	ld @0, Z+
	ld @1, Z
.ENDMACRO


.dseg
SecondCounter: 	.byte 2
TempCounter: 	.byte 2
RevCounter: 	.byte 2

.cseg
.org 0
	rjmp RESET
	nop
	rjmp EXT_INT0
	nop
	reti
	nop
	reti
	nop
	reti
	nop
	reti    ; 5
	nop
	reti
	nop
	reti
	nop
	reti
	nop
	reti
	nop
	reti	;10
	nop
	reti
	nop
	reti
	nop
	reti
	nop
	reti
	nop
	reti	;15
	nop
	rjmp Timer0OverFlow
	nop

RESET:
	ldi tmp, high(RAMEND)
	out SPH, tmp
	ldi tmp, low(RAMEND)
	out SPL, tmp

	ldi tmp, (2 << ISC00)
	; set INT0 as falling edge triggered interrupt
	sts EICRA, tmp
	in tmp, EIMSK
	; enable INT0
	ori tmp, (1<<INT0)
	out EIMSK, tmp


	;DEBUG
	clr secondToggle

	out PORTD, tmp ; Enable pull-up resistors on PORTD
	clr tmp
	out DDRD, tmp ; PORTD is input

	ser tmp
	out DDRC, tmp	; PORTC as output (LEDs)
	;out PORTC, tmp	; debug
	clr tmp
	out DDRD, tmp	; PORTD for input (the emitter-detector)

	rjmp MAIN

EXT_INT0:		; interrupt subroutine for InfraRed RevCounter

	; Prologue: save conflict registers
	in tmp, SREG
	push tmp
	push YL
	push YH
	push r25
	push r24

	;Load the RevCounter value
	ldi YL, low(RevCounter)
	ldi YH,	high(RevCounter)
	ld r24, Y+
	ld r25, Y

	adiw r25:r24, 1	; RevCounter++


	;DEBUG - we should at least see 4 leds light up
	;when interrupt is triggered
	;ldi tmp, 0xF
	;out PORTC, tmp

	
	st y, r25
	st -y, r24

	pop r24
	pop r25
	pop YH
	pop YL
	pop tmp
	out SREG, tmp

	reti	; Return from RevCounterIRQ


Timer0OverFlow:		; interrupt subroutine for Timer0

	; Prologue: save conflict registers
	in tmp, SREG
	push tmp
	push YL
	push YH
	push r25
	push r24

	;Load the TempCounter value
	ldi YL, low(TempCounter)
	ldi YH,	high(TempCounter)
	ld r24, Y+
	ld r25, Y
	;LoadFromDataMem r24, r25, TempCounter

	adiw r25:r24, 1	; TempCounter++
	
	; check if we have reached a second
	cpi r24, low(3597)
	brne NotSecond
	ldi tmp, high(3597)
	cpc r25, tmp
	brne NotSecond

	; Have reached 1 second...

	Clear TempCounter	; reset counter
	ldi ZL, low(SecondCounter)
	ldi ZH, high(SecondCounter)
	ld r24, Z+
	ld r25, Z

	;LoadFromProgMem r24, r25, SecondCounter
	adiw r25:r24, 1	; increment
	st Z, r25
	st -Z, r24

	; DISPLAY RPS (revs per second) and RESET RevCounter
	; for now just display speed in binary to leds
	;Load the RevCounter value
	ldi YL, low(RevCounter)
	ldi YH,	high(RevCounter)
	ld r24, Y+
	ld r25, Y
	
	;Divide by 4 as we only want to count every 4 hole we see
	lsr r25
	ror r24
	out PORTC, r24
	Clear RevCounter	; reset rev counter

	;ldi tmp, 0x0
	;out PORTC, tmp


	rjmp EndIf

	NotSecond:
		st y, r25
		st -y, r24

	EndIf:
		pop r24
		pop r25
		pop YH
		pop YL
		pop tmp
		out SREG, tmp

	reti	; Return from Timer0OverFlow


MAIN:
	;ldi leds, 0xFF
	;out PORTC, leds
	

	Clear TempCounter
	Clear SecondCounter
	Clear RevCounter

	ldi tmp, 0b00000010 ; Prescale timer value
	out TCCR0, tmp		; to 8 = 256*8/7.3728
	ldi tmp, 1<<TOIE0	; = 278 microseconds
	out TIMSK, tmp		; T/C0 interrupt enable
	sei					; Enable global interrupts
	clr tmp

LOOP:
	rjmp LOOP

;EXT_INT0: 
;	rjmp RevCounterIRQ

;	reti
