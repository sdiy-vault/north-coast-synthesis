.psize 44,144
.title "LED blinker"
.sbttl "$Id: ledblink.s 9758 2022-01-08 17:01:16Z mskala $"
; Copyright (C) 2022  Matthew Skala
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, version 3.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Matthew Skala
; https://northcoastsynthesis.com/
; mskala@northcoastsynthesis.com
;

.include "global.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "RAM data"

.global LEDBLINK_TRIS7, LEDBLINK_TRIS9, LEDBLINK_RB7, LEDBLINK_RB9
.section .bss
LEDBLINK_TRIS7:	.skip 2
LEDBLINK_TRIS9:	.skip 2
LEDBLINK_RB7:	.skip 2
LEDBLINK_RB9:	.skip 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "LED blinker API"

; Steps to use this:
;   * call LEDBLINK_INIT to activate timers and interrupts
;   * this uses Timers 1 and 2, and their interrupts
;   * put blink patterns in LEDBLINK_TRIS{7,9} and LEDBLINK_RB{7,9}
;   * bit 1 in TRIS for off; otherwise bit 1 in RB for green, 0 for red
;   * it scans through the patterns from bit 0 up to 15 at 15.258 Hz
;   * call LEDBLINK_DONE to shut it down

.section .text

.global LEDBLINK_INIT
LEDBLINK_INIT:
	; default blink pattern is solid off, default colour is green
	mov	#LEDBLINK_TRIS7, W0
	repeat	#3
	setm	[W0++]

	; enable Timer 1 and 2 interrupts
	; priority 2 is set in power-on reset
	bset	IEC0, #T1IE
	bset	IEC0, #T2IE

	return

.global LEDBLINK_DONE
LEDBLINK_DONE:
	; disable Timer 1 and 2 interrupts
	bclr	IEC0, #T1IE
	bclr	IEC0, #T2IE

	; turn off LEDs
	bset	TRISB, #7
	bset	TRISB, #9

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "LED blinker ISR"

.section .isr, code

; T2 should overflow on the offbeats of T1, so this ISR sets T2 to halfway
; through its period of 0x1000, every time T1 overflows
.global __T1Interrupt
__T1Interrupt:
	bclr	IFS0, #T1IF
	clr	TMR2		; do it this way so we needn't use wregs
	bset	TMR2, #11
	retfie

.global __T2Interrupt
__T2Interrupt:
	push	W0
	push	W1

	bclr	IFS0, #T2IF

	mov	TMR1, W0	; get top four bits of TMR1
	lsr	W0, #12, W0

	mov	#LEDBLINK_TRIS7, W1

	btst.c	[W1++], W0
	bra	nc, 1f
	bset	TRISB, #7
	bra	2f
1:
	bclr	TRISB, #7
2:

	btst.c	[W1++], W0
	bra	nc, 1f
	bset	TRISB, #9
	bra	2f
1:
	bclr	TRISB, #9
2:

	btst.c	[W1++], W0
	bra	nc, 1f
	bset	LATB, #7
	bra	2f
1:
	bclr	LATB, #7
2:

	btst.c	[W1++], W0
	bra	nc, 1f
	bset	LATB, #9
	bra	2f
1:
	bclr	LATB, #9
2:

	bset	SOFT_INT_FLAGS, #SI_BLINK1
	bset	SOFT_INT_FLAGS, #SI_BLINK2

	bra	RETFIE_W0_1

.end
