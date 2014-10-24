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

.def rate = r23

.cseg
.org 0
	jmp RESET
	
.include "lcd.asm"	; optional
.include "keypad.asm"
	

RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	
	rcall KEYPAD_INIT
	rcall lcd_init

	; Init PWM for motor control
	ldi temp, 0b10000000
	out DDRB, temp		; Bit 7 will function as OC2.
	ldi rate, 0x4A		; the value controls the PWM duty cycle
	out OCR2, rate
	; Set the Timer2 to Phase Correct PWM mode.
	ldi temp, (1<< WGM20)|(1<<COM21)|(1<<CS20)
	out TCCR2, temp
	
	out DDRC, temp ; Make PORTC all outputs
	rjmp main


MAIN:
	;read number from keypad
	out PORTC, rate	; debug, LEDs
	
	; Show rate value on LCD
	cp number, rate
	breq DONT_REFRESH
		rcall LCD_RESET
		mov number, rate
		rcall LCD_DISPLAY_NUMBER
	
	DONT_REFRESH:
		rcall READ_KEYPAD
		jmp MAIN


ON_KEY_PRESS:
; When an key is pressed do something with it.

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
		subi rate, -1	; increased by 10 rps?
		out OCR2, rate
		rjmp DONE
		
	SLOWER:
		subi rate, 1	; decreased by 10 rps?
		out OCR2, rate
		rjmp DONE
	
	STOP:
		ldi rate, 0x01	; stop
		out OCR2, rate
		rjmp DONE

	THIRTY:
		ldi rate, 0x4A	; 30 rps?
		out OCR2, rate
		;rjmp DONE
	
	DONE:
	ret
