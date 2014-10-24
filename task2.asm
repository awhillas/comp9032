;------------------------------------------------------------------------------
; Lab 4, Task 2 v.0.3b
; -------------------
; Using Timer0 to do the count down till 1 second.
; 
; Using an external interrupt zero to count motor revolutions with the emitter
; detector.
;
; WIRING
; ------
; OpD -> PD0
; OpE -> PB0
; Mot -> Pot
; LCD D0-D7 -> PD0-PD7
; LCD BE-RS -> PE0-PE3
; Optional:
; LED LED0-LED7 -> PC0-PC7
;------------------------------------------------------------------------------

.include "m64def.inc"
.include "lcd.inc"

.def temp = r16
.def leds = r17
.def secondToggle = r18
.def number = r19

; Clear a word in memory
; param @0 = mem. addr. to clear
.MACRO Clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp
	st y+, temp
	st y, temp
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
.org 0x100	;starting address of data segment to 0x100
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

.include "lcd.asm"	; optional

RESET:
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp

	ldi temp, (2 << ISC00)
	; set INT0 as falling edge triggered interrupt
	sts EICRA, temp
	in temp, EIMSK
	; enable INT0
	ori temp, (1<<INT0)
	out EIMSK, temp


	;DEBUG
	clr secondToggle

	out PORTD, temp	; Enable pull-up resistors on PORTD
	clr temp
	out DDRD, temp	; PORTD for input (the emitter-detector)

	ser temp
	out DDRC, temp	; PORTC as output (LEDs)
	out PORTC, temp	; debug

	rcall lcd_init
	rcall LCD_RESET
	rjmp MAIN

EXT_INT0:		; interrupt subroutine for InfraRed RevCounter

	; Prologue: save conflict registers
	in temp, SREG	; Save the Status Register
	push temp
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

	; DEBUG - we should at least see 4 leds light up
	; when interrupt is triggered
	ldi temp, 0xF
	out PORTC, temp

	; Save the RevCounter value
	st Y, r25
	st -Y, r24

	pop r24
	pop r25
	pop YH
	pop YL
	pop temp
	out SREG, temp

	reti	; Return from RevCounterIRQ


Timer0OverFlow:		; interrupt subroutine for Timer0

	; Prologue: save conflict registers
	in temp, SREG	; Save the Status Register
	push temp
	push YL
	push YH
	push r25
	push r24

	; Load the TempCounter value
	ldi YL, low(TempCounter)
	ldi YH,	high(TempCounter)
	ld r24, Y+
	ld r25, Y
	; LoadFromDataMem r24, r25, TempCounter

	adiw r25:r24, 1	; TempCounter++

	; check if we have reached a second
	cpi r24, low(3597)
	brne NotSecond
	ldi temp, high(3597)
	cpc r25, temp
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
	lsr r25
	ror r24
	mov leds, r24
	out PORTC, r24
	Clear RevCounter	; reset rev counter

	;ldi temp, 0x0
	;out PORTC, temp


	rjmp EndIf

	NotSecond:
		st y, r25
		st -y, r24

	EndIf:
		pop r24
		pop r25
		pop YH
		pop YL
		pop temp
		out SREG, temp

	reti	; Return from Timer0OverFlow


MAIN:
	;ldi leds, 0xFF
	;out PORTC, leds


	Clear TempCounter
	Clear SecondCounter
	Clear RevCounter

	ldi temp, 0b00000010 ; Prescale timer value
	out TCCR0, temp		; to 8 = 256*8/7.3728
	ldi temp, 1<<TOIE0	; = 278 microseconds
	out TIMSK, temp		; T/C0 interrupt enable
	sei					; Enable global interrupts
	clr temp

LOOP:
	cp number, leds
	breq DONT_REFRESH
		rcall LCD_RESET
		mov number, leds
		rcall LCD_DISPLAY_NUMBER

	DONT_REFRESH:	
	rjmp LOOP

;EXT_INT0:
;	rjmp RevCounterIRQ

;	reti
