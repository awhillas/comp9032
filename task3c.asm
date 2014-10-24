;------------------------------------------------------------------------------
; Lab4, Task3 mark2
; =================
; Control motor speed with keypad: 1 = fast, 2 = slaower, 3 = stop, 4 = 30rps.
; Taken task 1 and modified it (as its working) to do task 3.

; WIRING
; ------
; PB7 -> Mot
; Keypad R0-C3 -> PA0-PA7
; and these are optional for the task...
; LCD D0-D7 -> PD0-PD7
; LCD BE-RS -> PE0-PE3
; LEDs LED0-LED7 -> PC1-PC7

; These ports can be changed if required by replacing all references to the
; ports with a different port. See: keypad.inc (KP_DDR, KP_PORT, KP_PIN) and
; lcd.inc (LCD_DATA_*, LCD_CTRL_*)

; Some defs were changed to avoid clashes
;------------------------------------------------------------------------------

.include "m64def.inc"
.include "lcd.inc"
.include "keypad.inc"

.def rate = r16

; Clear a word in memory
; param @0 = mem. addr. to clear
.MACRO Clear
	ldi YL,low(@0)
	ldi YH,high(@0)
	clr temp
	st y+, temp
	st y, temp
.ENDMACRO

.MACRO LoadMotorRate
	ldi YL, low(MotorRate)
	ldi YH,	high(MotorRate)
	ld r16, Y+
	ld r17, Y
.ENDMACRO

.MACRO SaveMotorRate
	ldi YL, low(MotorRate)
	ldi YH,	high(MotorRate)
	st y, r17
	st -y, r16
.ENDMACRO

.dseg
.org 0x100	;starting address of data segment to 0x100
	SecondCounter: 	.byte 2
	TempCounter: 	.byte 2
	RevCounter: 	.byte 2
	MotorRate:		.byte 2

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
.include "keypad.asm"
	

RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	
	rcall KEYPAD_INIT
	rcall lcd_init
	
	; Setup IR detector
	ldi temp, (2 << ISC00)
	; set INT0 as falling edge triggered interrupt
	sts EICRA, temp
	in temp, EIMSK
	; enable INT0
	ori temp, (1<<INT0)
	out EIMSK, temp
	
	; Setup interupt PORTD?
	out PORTD, temp	; Enable pull-up resistors on PORTD
	clr temp
	out DDRD, temp	; PORTD for input (the emitter-detector)

	Clear TempCounter
	Clear SecondCounter
	Clear RevCounter
	Clear Rate

	; Setup Timer0
	ldi temp, 0b00000010 ; Prescale timer value
	out TCCR0, temp		; to 8 = 256*8/7.3728
	ldi temp, 1<<TOIE0	; = 278 microseconds
	out TIMSK, temp		; T/C0 interrupt enable
	sei					; Enable global interrupts
	clr temp

	; Init PWM for motor control
	ldi temp, 0b10000000
	out DDRB, temp		; Bit 7 will function as OC2.
	ldi rate, 0x7C		; the value controls the PWM duty cycle
	out OCR2, rate
	clr r17
	SaveMotorRate
	; Set the Timer2 to Phase Correct PWM mode.
	ldi temp, (1<< WGM20)|(1<<COM21)|(1<<CS20)
	out TCCR2, temp


MAIN:
	; Show rate value on LCD
	LoadMotorRate
	cp number, rate
	breq DONT_REFRESH
		rcall LCD_RESET
		mov number, rate
		rcall LCD_GOTO_LINE2
		rcall LCD_DISPLAY_NUMBER
	SaveMotorRate
	DONT_REFRESH:
		rcall READ_KEYPAD
		jmp MAIN


ON_KEY_PRESS:
; When an key is pressed do something with it.
	LoadMotorRate

	cpi input, '1'
	breq FASTER
	cpi input, '2'
	breq SLOWER
	cpi input, '3'
	breq STOP
	cpi input, '4'
	breq THIRTY
	rjmp DONE
	
	FASTER:
		subi rate, -25	; increased by 10 rps?
		out OCR2, rate
		rjmp DONE
		
	SLOWER:
		subi rate, 25	; decreased by 10 rps?
		out OCR2, rate
		rjmp DONE
	
	STOP:
		ldi rate, 0x01	; stop
		out OCR2, rate
		rjmp DONE

	THIRTY:
		ldi rate, 0x7C	; 30 rps?
		out OCR2, rate
		;rjmp DONE
	
	DONE:
	SaveMotorRate
	ret

EXT_INT0:		; interrupt subroutine for InfraRed RevCounter

	; Prologue: save conflict registers
	in temp, SREG
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

	st y, r25
	st -y, r24

	pop r24
	pop r25
	pop YH
	pop YL
	pop temp
	out SREG, temp

	reti	; Return from RevCounterIRQ


Timer0OverFlow:		; interrupt subroutine for Timer0

	; Prologue: save conflict registers
	in temp, SREG
	push temp
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
	;;out PORTC, r24


	; Show rate value on LCD
	rcall LCD_RESET
	mov number, r24
	rcall LCD_DISPLAY_NUMBER


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
