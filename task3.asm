; Lab 4, Task 3 - Control the motor with the keyboard
;
; Board Wiring
;
.include "m64def.inc"
.include "keypad_defs.inc"

.def temp = r16
;.def rate = r24


.cseg
.org 0
	rjmp RESET

.include "keypad.asm"

RESET:
	; Init. stack
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	rcall INIT_KEYPAD

	; setup LEDs on PORTC for debug output
	ser temp
	out DDRC, temp
	out PORTC, temp

	; Motor setup (PWM)
	; ldi temp, 0b10000000
	; out DDRB, temp		; Bit 7 will function as OC2.
	; ldi rate, 0x4A		; the value controls the PWM duty cycle
	; out OCR2, rate
	; ; Set the Timer2 to Phase Correct PWM mode.
	; ldi temp, (1<< WGM20)|(1<<COM21)|(1<<CS20)
	; out TCCR2, temp

;	ldi rate, 0xAA

MAIN:
	rcall READ_KEYPAD
	rjmp MAIN
	
END:
	rjmp END

ON_KEY_PRESS:
; Called from keypad.asm
; expect a ascii char in `input` reg.
	; subi rate, 100	; the value controls the PWM duty cycle
	; out OCR2, rate
	; ;out PORTC, rate
	; ldi temp, (1<< WGM20)|(1<<COM21)|(1<<CS20)
	; out TCCR2, temp
	
	out PORTC, input

	ret

