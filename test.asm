.include "m64def.inc"

.def tmp = r16
.def tmp2 = r16

.cseg
.org 0
	rjmp MAIN

MAIN:
	clr tmp
	ldi tmp,1
	ldi tmp2, 2

END:
	rjmp END
