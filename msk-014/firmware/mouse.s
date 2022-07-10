.psize 44,144
.title "Mouse device driver"
.sbttl "$Id: mouse.s 9774 2022-01-20 22:39:48Z mskala $"
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
.sbttl "TPL entry"

.pushsection til_mouse, code
	mov	#handle(mouse_driver), W4
	mov	#0x0103, W5	; class 3 "HID", subclass 1 "boot"
	mov	#2, W6		; protocol 2 "mouse"
	rcall	TPL_MATCH_CLASS_AND_PROTOCOL
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Data structures and constants"

.equ MOUSE_SCALE_MULTIPLIER, 12
.equ MOUSE_SCALE_DIVISOR, 10

.equ STARTING_NOTE, 0x3C00
.equ LOW_NOTE, 0x2400
.equ HIGH_NOTE, 0x6000

.equ DIATONIC_SCALE, 0x0AD5

in_common	int_ep, ENDPOINT_SIZE
in_common	buttons, 2	; old button status in high byte
in_common	key, 2
in_common	fourths, 2
in_common	sevenths, 2
in_common	mode, 2
in_common	abs_x, 2
in_common	abs_y, 2
in_common	int_irp, IRP_SIZE
in_common	buffer, 8+BUFFER_SAFETY_MARGIN

.equ start_init, buttons

.pushsection *, code
	; four words of zeros before this
data_template:
	.word	3		; mode
	.word	STARTING_NOTE	; abs_x
	.word	STARTING_NOTE	; abs_y

	; INTR IRP
	.word	IRPFM_INTR	; flags
	.word	3		; three-byte boot mouse report
	.word	buffer		; buffer address
	.word	0		; fill point
end_template:
.popsection

;
; Working register usage in this driver:
;
; W0-W3    - general use, subroutine arguments
; W4       - pointer into buffer, argument for USB_WAIT_ON_IRP
; W5       - used in movement scaling, argument for USB_WAIT_ON_IRP
; W6, W7   - quantized absolute X and Y
; W8       - diatonic scale bitmap
; W9, W10  - key-relative notes returned by quantize_to_key
; W11      - interrupt delay in milliseconds
; W12, W13 - unassigned
; W14      - frame pointer
; W15      - stack pointer
;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Driver init and mouse input"

.section .text

mouse_driver:
	; configure the device to use its simplified protocol
	mov	#int_ep, W8
	mov	#1, W9
	rcall	USB_CONFIGURE_DEVICE
	rcall	USB_SET_BOOT_PROTOCOL

	; initialize data
	mov	#tbloffset(data_template), W1
	mov	#start_init, W2
	repeat	#3
	clr	[W2++]	; four words of zeros at start
	repeat	#((end_template-data_template)/2)-1
	tblrdl	[W1++], [W2++]

	; set delay time
	mov	int_ep+12, W11	; get recommendation from descriptor
	mov	#5, W0		; if it's less than 5ms, use 5ms
	cpslt	W0, W11
	mov	W0, W11
	mov	#200, W0	; if it's more than 200ms, use 200ms
	cpslt	W11, W0
	mov	W0, W11

	rcall	PPS_MAP_GPIO_DOUT	; prepare to send gates

	clr.b	buffer		; assume buttons start unclicked

driver_loop:
	mov	W11, W0	; wait for time to do another INTR IN
	rcall	USB_LOOP_WAIT

	clr.b	buffer+1	; to avoid drift on short report
	clr.b	buffer+2

	mov	#(IRPFM_INTR|IRPFM_UOWN), W1	; flags for INTR IN
	mov	#3, W2		; buffer length 3
	mov	#int_ep, W4	; endpoint
	mov	#int_irp, W5	; IRP 
	rcall	USB_WAIT_ON_IRP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Mouse report decoding"

	mov	#(buffer+1), W4	; pointer to the X byte
	se	[W4++], W0	; get the X byte, sign extended

	rcall	scale_offset
.pushsection *, code
scale_offset:
	; scale the offset from the mouse
	mul.su	W0, #MOUSE_SCALE_MULTIPLIER, W2
	mov	#MOUSE_SCALE_DIVISOR, W5
	repeat	#17
	div.s	W2, W5
	return
.popsection

	mov	abs_x, W1	; apply the offset
	add	W0, W1, W0

	rcall	clamp_coordinate
.pushsection *, code
; round_flip moved here to allow fall-through, see its use in mode 1 below
round_flip:
	cpslt	W1, W0
	inc2.b	WREG0H		; if we rounded down, round up now
	dec.b	WREG0H		; else round down now
;	bra	clamp_coordinate	; and don't go past end, tail call
	; FALL THROUGH

clamp_coordinate:
	mov	#LOW_NOTE, W1	; clamp low side
	cpslt	W1, W0
	mov	W1, W0
	mov	#HIGH_NOTE, W1	; clamp high side
	cpslt	W0, W1
	mov	W1, W0
	return
.popsection
	mov	W0, abs_x

	se	[W4], W0	; get the Y byte, sign extended
	rcall	scale_offset
	mov	abs_y, W1	; apply the offset
	sub	W1, W0, W0
	rcall	clamp_coordinate
	mov	W0, abs_y

	mov.b	buttons, WREG	; get old button status
	swap	W0		; swap it into high byte
	mov.b	buffer, WREG	; get new button status
	mov	W0, buttons	; save the new and old button status

	btst	W0, #10		; was middle button unclicked last time?
	bra	nz, 1f
	btsc	W0, #2		; is it clicked now?
	inc	mode		; if it's newly clicked, bump the mode
1:

	; quantize coordinates as a starting point
	mov	#0x80, W0
	mov	abs_x, W1
	add	W1, W0, W6
	clr.b	WREG6L
	mov	abs_y, W1
	add	W1, W0, W7
	clr.b	WREG7L

	btst	mode, #1	; decide between modes {0,1} and {2,3}
	bra	nz, mode_2

	bclr	LATB, #7	; left LED red

	btst	mode, #0	; decide between modes 0 and 1
	bra	nz, mode_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "MODE 0 - smart quantize"

	bclr	LATB, #9	; right LED red

	; MODE 0 - smart quantize

	rcall	quantize_to_key	; puts key-relative notes in W9 and W10

	btst	buttons, #8	; did we newly release button 1?
	bra	z, 1f
	btst	buttons, #0
	bra	nz, 1f

	rcall	look_for_key_change_notes
.pushsection *, code
look_for_key_change_notes:
	cp	W9, #5		; perfect fourth = five semitones
	bra	nz, 2f
	inc	fourths
	clr	sevenths
2:

	cp	W9, #11		; major seventh = eleven semitones
	bra	nz, 2f
	inc	sevenths
	clr	fourths
2:
	return
.popsection
1:

	btst	buttons, #9	; did we newly release button 2?
	bra	z, 1f
	btst	buttons, #1
	bra	nz, 1f
	mov	W10, W9
	rcall	look_for_key_change_notes
1:
	mov	#3, W0		; have we seen three perfect fourths?
	cp	fourths
	bra	ltu, 1f
	mov	#0x0700, W0	; if so, shift to subdominant key
	bra	2f

1:
	cp	sevenths	; have we seen three major sevenths?
	bra	ltu, do_output
	mov	#0x0500, W0	; if so, shift to dominant key

2:
	add	key, WREG	; apply the chosen shift to the key offset
	rcall	mod_c00
	swap	W0
	mov	W0, key

	bra	clr_fourths_and_sevenths	; shared with mode 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "MODE 1 - quantize to C major"

mode_1:
	bset	LATB, #9	; right LED green

	; MODE 1 - quantize to C major

	clr	key		; this mode always uses C, and resets mode 0

	rcall	quantize_to_key
.pushsection *, code
quantize_to_key:
	mov	#DIATONIC_SCALE, W8	; for reference

	mov	W6, W0		; look up X coordinate in scale
	add	key, WREG
	rcall	mod_c00
.pushsection *, code
; reduce unsigned high byte of W0 modulo 12 and return the residue in W0 (as
; a word, with all the higher bits zero).  Trashes W1 and W2.
mod_c00:
	mov	#0x0C00, W2
	repeat	#17
	div.uw	W0, W2
	lsr	W1, #8, W0
	return
.popsection
	mov	W0, W9
	lsr	W8, W0, W1
	btst	W1, #0
	bra	nz, 1f		; keep current quantization if in scale

	mov	W6, W0
	mov	abs_x, W1	; see which way we rounded
	rcall	round_flip
; round_flip is moved to join clamp_coordinate, but defined as follows
; round_flip:
;	cpslt	W1, W0
;	inc2.b	WREG0H		; if we rounded down, round up now
;	dec.b	WREG0H		; else round down now
;	bra	clamp_coordinate	; and don't go past end, tail call
	mov	W0, W6
1:

	mov	W7, W0		; look up Y coordinate in scale
	add	key, WREG
	rcall	mod_c00
	mov	W0, W10
	lsr	W8, W0, W1
	btst	W1, #0
	bra	nz, 1f		; keep current quantization if in scale

	mov	W7, W0
	mov	abs_x, W1	; see which way we rounded
	rcall	round_flip
	mov	W0, W7
1:

	return
.popsection

clr_fourths_and_sevenths:
	clr	fourths		; so mode 0 will restart in known state
	clr	sevenths

	bra	do_output

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "MODES 2 and 3 - quantize to semitones, and unquantized"

mode_2:
	bset	LATB, #7	; left LED green

	btst	mode, #0	; decide between modes 2 and 3
	bra	nz, mode_3

	bclr	LATB, #9	; right LED red

	; MODE 2 - quantize to semitones

	; do nothing - semitone quantized values are already in W6 and W7

	bra	do_output

mode_3:
	bset	LATB, #9	; right LED green

	; MODE 3 - unquantized

	mov	abs_x, W6	; restore the unquantized values
	mov	abs_y, W7

	; bra	do_output
	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Result output"

do_output:
	; left LED and gate
	btst	buttons, #0	; check button 1
	bra	nz, 1f
	bclr	LATB, #14	; gate 1 low when button 1 unclicked
	mov	abs_x, W6	; and use unquantized X coordinate
	btst	buttons, #2	; button 3 overrides 1 to light LED
	bra	nz, 2f
	bset	TRISB, #7	; left LED off when neither 1 nor 3 clicked
	bra	3f
1:
	bset	LATB, #14	; gate 1 high when button 1 clicked
2:
	bclr	TRISB, #7	; left LED on when 1 or 3 clicked
3:

	; right LED and gate
	btst	buttons, #1	; check button 2
	bra	nz, 1f
	bclr	LATB, #8	; gate 2 low when button 2 unclicked
	mov	abs_y, W7	; and use unquantized Y coordinate
	btst	buttons, #2	; button 3 overrides 2 to light LED
	bra	nz, 2f
	bset	TRISB, #9	; right LED off when neither 2 nor 3 clicked
	bra	3f
1:
	bset	LATB, #8	; gate 2 high when button 2 clicked
2:
	bclr	TRISB, #9	; right LED on when 2 or 3 clicked
3:

	; send coordinates to DACs
	mov	W6, W0
	rcall	NOTENUM_TO_DAC1
	mov	W7, W0
	rcall	NOTENUM_TO_DAC2

	bra	driver_loop

.end
