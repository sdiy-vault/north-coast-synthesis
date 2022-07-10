.psize 44,144
.title "Typing keyboard device driver"
.sbttl "$Id: qwerty.s 9758 2022-01-08 17:01:16Z mskala $"
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

.pushsection til_qwerty, code
	mov	#handle(qwerty_driver), W4
	mov	#0x0103, W5	; class 3 "HID", subclass 1 "boot"
	mov	#1, W6		; protocol 1 "keyboard"
	rcall	TPL_MATCH_CLASS_AND_PROTOCOL
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Key tables"

.pushsection *, code
press_tbl_start:
.equ PRESS_TBL_START, .
	; 00 - 03  reserved and error values
	; 04 - 1D  letters
	; 1E - 27  numerals

	.word second_return_insn	; 28 Enter
	.word channel_press		; 29 Esc
	.word note_press		; 2A backspace
	.word note_press		; 2B Tab
	.word second_return_insn	; 2C space

	.word note_press		; 2D -_
	.word note_press		; 2E =+
	.word note_press		; 2F [{
	.word note_press		; 30 ]}
	.word note_press		; 31 US \| (left of backspace)

	.word note_press		; 32 ISO #~ (left of Enter)

	.word note_press		; 33 ;:
	.word note_press		; 34 '"
	.word note_press		; 35 `~
	.word note_press		; 36 ,<
	.word note_press		; 37 .>
	.word note_press		; 38 /?

	.word sustain_press		; 39 Caps Lock

	.word channel_press		; 3A function F1
	.word channel_press		; 3B function F2
	.word channel_press		; 3C function F3
	.word channel_press		; 3D function F4
	.word channel_press		; 3E function F5
	.word channel_press		; 3F function F6
	.word channel_press		; 40 function F7
	.word channel_press		; 41 function F8
	.word channel_press		; 42 function F9
	.word channel_press		; 43 function F10
	.word channel_press		; 44 function F11
	.word channel_press		; 45 function F12

	.word channel_press		; 46 Print Screen/Sys Rq
	.word channel_press		; 47 Scroll Lock
	.word channel_press		; 48 Pause/Break

	.word second_return_insn	; 49 Insert
	.word second_return_insn	; 4A Home
	.word second_return_insn	; 4B Page Up
	.word second_return_insn	; 4C Delete
	.word second_return_insn	; 4D End
	.word second_return_insn	; 4E Page Down

	.word second_return_insn	; 4F right arrow
	.word second_return_insn	; 50 left arrow
	.word second_return_insn	; 51 down arrow
	.word second_return_insn	; 52 up arrow

	.word iso_mode_press		; 53 Num Lock

	.word second_return_insn	; 54 keypad /
	.word second_return_insn	; 55 keypad *
	.word second_return_insn	; 56 keypad -
	.word second_return_insn	; 57 keypad +
	.word second_return_insn	; 58 keypad Enter
	.word velocity_press		; 59 keypad 1 End
	.word velocity_press		; 5A keypad 2 down arrow
	.word velocity_press		; 5B keypad 3 Pg Dn
	.word velocity_press		; 5C keypad 4 left arrow
	.word velocity_press		; 5D keypad 5
	.word velocity_press		; 5E keypad 6 right arrow
	.word velocity_press		; 5F keypad 7 Home
	.word velocity_press		; 60 keypad 8 up arrow
	.word velocity_press		; 61 keypad 9 Pg Up
	.word keypad_ins_press		; 62 keypad 0 Ins
	.word second_return_insn	; 63 keypad . Del

	.word note_press		; 64 ISO \| (right of left Shift)

	; 65       menu
	; 66 - DF  misc. keys not in typical PC layouts
	; E0 - E7  modifier keys considered as pressable
	; E8 - FFFF  reserved

.equ PRESS_TBL_END, .

.equ PRESS_TBL_MIN, 0x28
.equ PRESS_TBL_MAX, 0x64

.if (PRESS_TBL_MAX-PRESS_TBL_MIN+1)*2 != (PRESS_TBL_END-PRESS_TBL_START)
  .error "Key-press table is the wrong length"
.endif
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.pushsection *, code
	; this entry is special-cased, allowing the table to be much smaller
	.word 0x342F	; 64 ISO \| (right of left Shift)
note_tbl_start:
.equ NOTE_TBL_START, .
	; 00 - 03  reserved and error values

	.word 0x3B30	; 04 letter A
	.word 0x3E37	; 05 letter B
	.word 0x3A34	; 06 letter C
	.word 0x3F33	; 07 letter D
	.word 0x4440	; 08 letter E
	.word 0x4135	; 09 letter F
	.word 0x4336	; 0A letter G
	.word 0x4538	; 0B letter H
	.word 0x4E48	; 0C letter I
	.word 0x473A	; 0D letter J
	.word 0x493C	; 0E letter K
	.word 0x4B3D	; 0F letter L
	.word 0x423B	; 10 letter M
	.word 0x4039	; 11 letter N
	.word 0x504A	; 12 letter O
	.word 0x524C	; 13 letter P
	.word 0x403C	; 14 letter Q
	.word 0x4641	; 15 letter R
	.word 0x3D31	; 16 letter S
	.word 0x4843	; 17 letter T
	.word 0x4C47	; 18 letter U
	.word 0x3C35	; 19 letter V
	.word 0x423E	; 1A letter W
	.word 0x3832	; 1B letter X
	.word 0x4A45	; 1C letter Y
	.word 0x3630	; 1D letter Z

	.word 0x453C	; 1E numeral 1
	.word 0x473D	; 1F numeral 2
	.word 0x493F	; 20 numeral 3
	.word 0x4B41	; 21 numeral 4
	.word 0x4D42	; 22 numeral 5
	.word 0x4F44	; 23 numeral 6
	.word 0x5146	; 24 numeral 7
	.word 0x5348	; 25 numeral 8
	.word 0x5549	; 26 numeral 9
	.word 0x574B	; 27 numeral 0

	.word 0xFFFF	; 28 Enter
	.word 0xFFFF	; 29 Esc
	.word 0x5F51	; 2A backspace
	.word 0x3E3B	; 2B Tab
	.word 0xFFFF	; 2C space

	.word 0x594D	; 2D -_
	.word 0x5B4E	; 2E =+
	.word 0x544D	; 2F [{
	.word 0x564F	; 30 ]}
	.word 0x5D50	; 31 US \| (left of backspace)

	.word 0x5142	; 32 ISO #~ (left of Enter)

	.word 0x4D3F	; 33 ;:
	.word 0x4F41	; 34 '"
	.word 0x433A	; 35 `~
	.word 0x443C	; 36 ,<
	.word 0x463E	; 37 .>
	.word 0x4840	; 38 /?

	; 39       Caps Lock
	; 3A - 45  function keys
	; 46 - 48  Print Screen, Scroll Lock, Pause/Break
	; 49 - 52  cursor controls
	; 53       Num Lock
	; 54 - 63  keypad

	; moved to just before start of table
	; .word 0x342F	; 64 ISO \| (right of left Shift)

	; 65       menu
	; 66 - DF  misc. keys not in typical PC layouts
	; E0 - E7  modifier keys considered as pressable
	; E8 - FFFF  reserved

.equ NOTE_TBL_END, .

.equ NOTE_TBL_MIN, 0x04
.equ NOTE_TBL_MAX, 0x38

.equ NOTE_KEY_MIN, NOTE_TBL_MIN
.equ NOTE_KEY_MAX, 0x64

.if (NOTE_TBL_MAX-NOTE_TBL_MIN+1)*2 != (NOTE_TBL_END-NOTE_TBL_START)
  .error "Note table is the wrong length"
.endif
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Maintenance code table"

; other source files can add to this table by putting 4-byte entries in a
; section named "mtbl" or like "mtbl_*".

; RESET and THROW codes are defined here instead of elsewhere because linker
; doesn't like to include an empty section in its output

.pushsection _mtbl_init, code
maint_tbl_start:
	; code 8605:  simulate power-on reset
	.word	0x8605, RESET_INSN
.popsection

.pushsection _mtbl_done, code
	; code 8189:  throw an exception from driver
	.word	0x8189, THROW
maint_tbl_end:
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "RAM data structures"

; note int_in_ep_ptr, int_out_ep_ptr, and int_ep_1 must be laid out in any
; driver that uses FIND_IN_OUT_ENDPOINTS the same way they are laid out
; here, even if other drivers use different names for these fields

; pointers to which EP is input (must exist per spec) and which is the
; optional output EP (or null if none)
in_common	int_in_ep_ptr, 2
in_common	int_out_ep_ptr, 2

; two endpoints for communicating with USB keyboard
in_common	int_ep_1, ENDPOINT_SIZE
in_common	int_ep_2, ENDPOINT_SIZE

; IRP for communicating with either EP
in_common	int_irp, IRP_SIZE

; notes currently playing on each key that can play notes; low byte is note
; number, low nibble of high byte is channel number.  Uses 0xFFFF as null
; value because note 0 in channel 0 is valid
in_common	key_notes, 2*(NOTE_KEY_MAX-NOTE_KEY_MIN+1)

; stuff from here to end is automatically cleared at init
.equ saved_loc, __common_loc

; buffer for longest USB message we will support
in_common	buffer, (8+BUFFER_SAFETY_MARGIN+1)&~1

; previous state for comparison to detect key up/down
in_common	previous_modifiers, 2
in_common	previous_keys, 6

; current modifier state for pitch bend handling
in_common	current_modifiers, 2

; ms delay the keyboard requests between polls
in_common	delay_time, 2

; keyboard LEDs, and previous state for detecting changes
in_common	leds, 1
in_common	previous_leds, 1

; currently selected MIDI channel
in_common	channel, 2

; current octave (as signed offset in semitones from default)
in_common	octave, 2

; current velocity
in_common	velocity, 2

; bits used during press/release detection; bit 0 of each word set if we
; see this key pressed now, bit 1 set if we saw it before.
in_common	key_flags, 512

; sustain (Caps Lock) state:  0 not locked; 1 key pressed to start lock;
; 2 key released, notes remain locked
in_common	sustain, 1

; low nibble is channel on which the sustain feature is active
in_common	sustain_channel, 1

; notes currently subject to sustain
in_common	sustained_notes, 256

; accumulates the maintenance code as it's entered, in BCD
in_common	maintenance_code, 2

; current pitch bend amount
in_common	pitch_bend, 2

.equ start_clear, buffer
.equ clear_length, __common_loc-saved_loc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Driver init"

.section .text

; Find first input, and first output, endpoints.  Assumes the common area is
; laid out as we did.  THROWs if W8 points at int_ep_1, indicating no
; endpoints known.
; Split into a subroutine so we can reuse it in other drivers.
.global FIND_IN_OUT_ENDPOINTS
FIND_IN_OUT_ENDPOINTS:
	mov	#int_ep_1, W1	; make sure we found at least one endpoint
	cp	W1, W8
	bra	z, THROW

	clr	W6		; return results in W6 and W7 as well as vars
	clr	W7

	mov	W1, int_in_ep_ptr	; need a dummy entry before list
	mov	#int_in_ep_ptr, W1

1:
	mov	[W1], W1	; get next endpoint in list
	cp0	W1		; if end of list, terminate
	bra	z, 1f

	inc2	W1, W0		; look at endpoint flags

	cp0	W6		; if we don't already have an input
	bra	nz, 2f
	btsc	[W0], #EPF_INPUT	; ...and this is an input...
	mov	W1, W6		; then save it
2:

	cp0	W7		; if we don't already have an output
	bra	nz, 1b		; (short-circuit end of loop)
	btss	[W0], #EPF_INPUT	; ...and this is an output...
	mov	W1, W7		; then save it

	bra	1b		; end of loop
1:

	mov	W6, int_in_ep_ptr	; save results to memory
	mov	W7, int_out_ep_ptr

	return

qwerty_driver:
	; configure device for one or two endpoints, set boot protocol
	mov	#int_ep_1, W8
	mov	#2, W9
	rcall	USB_CONFIGURE_DEVICE
	rcall	USB_SET_BOOT_PROTOCOL	; doesn't trash W8

	rcall	FIND_IN_OUT_ENDPOINTS

	cp0	int_in_ep_ptr	; we must have an input
	bra	z, COMPLAIN_ABOUT_DEVICE

	; clear data area
	mov	#key_notes, W0
	repeat	#(NOTE_KEY_MAX-NOTE_KEY_MIN)
	setm	[W0++]
	; mov	#start_clear, W0	; start_clear is just after key_notes
	repeat	#(clear_length/2)-1
	clr	[W0++]

	mov	#buffer, W0	; point IRP at buffer
	mov	W0, int_irp+4

	; set delay time
	mov	[W6+12], W1	; get recommendation from input descriptor
	mov	#2, W0		; if it's less than 2ms, use 2ms
	cpslt	W0, W1
	mov	W0, W1
	mov	#100, W0	; if it's more than 100ms, use 100ms
	cpslt	W1, W0
	mov	W0, W1
	mov	W1, delay_time

	mov	#71, W0		; set default velocity
	mov	W0, velocity

	setm.b	previous_leds	; force an LED update on first time around

	rcall	MIDI_INIT
	bset	USB_FLAGS, #UF_MIDI_BKGND

driver_loop:
	rcall	MIDI_BACKGROUND	; keep the MIDI backend happy

	pwrsav	#1		; wait for interrupt

	mov	delay_time, W0	; wait for time to do another INTR IN
	rcall	USB_LOOP_CHECK
	bra	z, driver_loop

	mov	#(IRPFM_INTR|IRPFM_UOWN), W1	; flags for INTR IN
	mov	#8, W2		; buffer length 8
	mov	int_in_ep_ptr, W4	; endpoint
	mov	#int_irp, W5	; IRP
	rcall	USB_WAIT_ON_IRP

	mov	int_irp+6, W0	; skip most key stuff if no keyboard update
	cp	W0, #8
	bra	lt, handle_lr_shift

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Process most modifier keys"

	; left Ctrl
	mov	octave, W0
	btst	previous_modifiers, #0	; if we weren't pressing it before
	bra	nz, 1f
	btst	buffer, #0	; and we are pressing it now
	bra	z, 1f
	mov	#-48, W1	; and we're not five octaves down already
	cpslt	W0, W1
	sub	W0, #12, W0	; then shift down another octave
1:

	; right Ctrl
	; value of W0 held over from above
	btst	previous_modifiers, #4	; if we weren't pressing it before
	bra	nz, 1f
	btst	buffer, #4	; and we are pressing it now
	bra	z, 1f
	mov	#36, W1		; and we're not four octaves up already
	cpslt	W1, W0
	add	W0, #12, W0	; then shift up another octave
1:
	mov	W0, octave	; save new octave value

	; left/right Alt
	; left/right GUI

	mov	buffer, W0	; save current modifiers for next time
	mov	W0, previous_modifiers

	; Ctrl+Alt unlocks maintenance codes
	lsr	W0, #4, W1	; OR of left and right modifiers
	ior	W0, W1, W0
	and	W0, #5, W0	; mask down to just Ctrl and Alt
	cp	W0, #5		; both must be on...
	bra	eq, 1f		; ...or else maintenance code is cleared
	clr	maintenance_code
1:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Process regular keys"

	; flag previously pressed

	mov	#key_flags, W13	; W13 is used throughout
	mov	#previous_keys, W11
	mov	#6, W12		; loop over six bytes

1:
	rcall	find_key_flags
.pushsection *, code
find_key_flags:
	ze	[W11++], W3	; put key code in W3
	sl	W3, #1, W0	; put twice key code in W0
	add	W0, W13, W1	; put address of flags word in W1
	return
; label for return preceded by another return; used for no-op in key table
second_return_insn:
	return
.popsection
	bset.b	[W1], #1	; set was-pressed flag

	dec	W12, W12	; end loop
	bra	gt, 1b

	; flag currently pressed, recognize which are newly pressed

	mov	#(buffer+2), W11
	mov	#6, W12		; loop over six bytes

1:
	rcall	find_key_flags
	btsts	[W1], #0	; flag as currently pressed
	bra	nz, 2f		; if we already knew that, skip key
	btst	[W1], #1	; check whether previously pressed
	bra	nz, 2f		; if it was, skip key

	; find entry in press table
	rcall	find_press_tbl_entry
.pushsection *, code
find_press_tbl_entry:
	cp	W3, #3		; check for reserved/error values
	bra	le, Z_RETURN

	mov	#PRESS_TBL_MIN, W5	; all else before table is notes
	cp	W3, W5
	bra	ge, 3f

	mov	#handle(note_press), W4	; return the note_press routine
	bra	NZ_RETURN

3:
	mov	#PRESS_TBL_MAX, W5	; check for values past end of table
	cp	W3, W5
	bra	gt, Z_RETURN

	mov	#tbloffset(press_tbl_start)-2*PRESS_TBL_MIN, W4
	add	W0, W4, W4
	tblrdl	[W4], W4	; find press subroutine

	bra	NZ_RETURN
.popsection
	bra	z, 2f
	call	W4

2:
	dec	W12, W12	; end loop
	bra	gt, 1b

	; unflag previously pressed, recognize which are newly released

	mov	#previous_keys, W11
	mov	#6, W12		; loop over six bytes

1:
	rcall	find_key_flags
	btst	[W1], #1	; check whether previously pressed
	bra	z, 2f		; if not previously pressed, skip
	bclr	[W1], #1	; only look at each such key once
	btst	[W1], #0	; check whether currently pressed
	bra	nz, 2f		; if currently pressed, skip

	rcall	find_press_tbl_entry
	bra	z, 2f
	dec2	W4, W4
	call	W4

2:
	dec	W12, W12	; end loop
	bra	gt, 1b

	; unflag currently pressed, save as next loop's "previous"

	mov	#(buffer+2), W11
	mov	#previous_keys, W2
	mov	#6, W12		; loop over six bytes

1:
	rcall	find_key_flags
	clr.b	[W1]		; clear flags
	mov.b	W3, [W2++]	; copy key code to "previous"

	dec	W12, W12	; end loop
	bra	gt, 1b

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Process left and right shift keys"

handle_lr_shift:
	clr	W0		; start adjustment rate at 0
	mov	pitch_bend, W3	; get current shift amount

	btsc	previous_modifiers, #1	; left shift = down at config rate
	sub	W0, #QWERTY_PBEND_RATE, W0
	btsc	previous_modifiers, #5	; right shift = up at config rate
	add	W0, #QWERTY_PBEND_RATE, W0

	clr	W2		; handy zero

	cp0	W0		; if no or both shifts, auto-return to zero
	bra	nz, 1f

	cp0	W3		; if at zero now, no need to auto-return
	bra	z, 2f

	cpslt	W3, W2		; auto-return at config rate
	mov	#-QWERTY_PBEND_RETURN, W0
	cpsgt	W3, W2
	add	W0, #QWERTY_PBEND_RETURN, W0

1:
	mov	delay_time, W4	; scale return rate to delay time
	mul.su	W0, W4, W0

	mov	W0, W4		; absolute value of change to W4
	cpsgt	W4, W2
	neg	W4, W4

	mov	W3, W5		; absolute value of current bend to W5
	cpsgt	W5, W2
	neg	W5, W5

	cp	W4, W5		; we can apply whole change if W4<W5
	bra	ltu, 1f

	mul.ss	W0, W3, W4	; we can apply whole change if away from 0
	cp0	W5
	bra	nn, 1f

	clr	W0		; but otherwise just go to zero
	clr	W3

1:

	add	W0, W3, W0	; update bend amount
	mov	#8192, W4	; this constant is used below
	cpslt	W0, W4
	dec	W4, W0
	mov	#-8193, W1
	cpsgt	W0, W1
	inc	W1, W0
	mov	W0, pitch_bend

	add	W0, W4, W2	; pack bend amount into data bytes
	sl	W2, W2
	lsr.b	W2, W2
	mov	channel, W1
	mov	#0x00E0, W3
	add	W1, W3, W1

	rcall	MIDI_READ_MESSAGE
2:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Keyboard LED update"

	; Num Lock LED managed by press/release code, lights in iso mode

	; Caps Lock LED lights iff sustain is active

	bclr	leds, #1	; initial guess:  off
	cp0.b	sustain		; toggle if sustain is active
	bra	z, 1f
	btg	leds, #1
1:

	; Scroll Lock LED lights iff "non-default octave" XOR "beat flash"

	bclr	leds, #2	; initial guess:  off
	btsc	BEAT_FLASH, #0	; toggle if "beat flash" state
	btg	leds, #2

	cp0	octave		; now toggle if non-default octave
	bra	z, 1f
	btg	leds, #2
1:

	mov.b	leds, WREG	; see if LEDs have changed
	cp.b	previous_leds
	bra	z, driver_loop
	mov.b	WREG, previous_leds

	cp0	int_out_ep_ptr	; see if we can use an INTR OUT
	bra	z, 1f

	mov	#(IRPFM_INTR|IRPFM_UOWN|IRPF_WRITE), W1	; flags for INTR OUT
	mov	#1, W2		; buffer length 1
	mov	int_out_ep_ptr, W4	; endpoint
	mov	#int_irp, W5	; IRP
	mov.b	WREG, buffer
	rcall	USB_WAIT_ON_IRP

	bra	driver_loop

1:
	mov	W0, W2		; no OUT endpoint, send it as CTRL instead
	rcall	USB_SET_REPORT
	bra	driver_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Press and release subroutines"

;
; Conventions for these:
;   - Entries in press_tbl point at the press subroutines
;   - The release subroutine must begin on the instruction immediately
;     previous to the press (so that will likely be a jump to the real
;     location, unless it's a no-op to make press and release equivalent, or
;     a return to make release a no-op)
;   - use "second_return_insn," which is a return preceded by another
;     return, as the press subroutine if press and release should both be
;     no-ops.
;   - Press and release subroutines should preserve W11-W15.
;   - On entry to press or release, W0 is twice the key code; W1 is pointer
;     to flags word; W3 is key code (zero extended).
;   - Press and release subroutines may trash W0-W10.
;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; note keys

	bra	note_release	; must be just before note_press
note_press:
	mov	#(2*NOTE_KEY_MAX), W1	; check for exceptional key
	cpsne	W0, W1
	mov	#(2*(NOTE_KEY_MIN-1)), W0	; and rewrite its value

	; figure out where the table would start if it started at zero
	mov	#tbloffset(note_tbl_start-NOTE_TBL_MIN*2), W1
	add	W0, W1, W1	; index into table
	tblrdl	[W1], W10

	btss	leds, #0	; check whether we're in isomorphic mode
	swap	W10		; and look at other byte if we are
	; the note we want to play ends up in W10 high byte

	mov	channel, W2	; put the channel in the low byte
	mov.b	W2, W10
	swap	W10		; and swap
	; at this point W10 high byte is channel, low byte is note

	mov	octave, W4	; apply octave shift
	add.b	W10, W4, W10
	mov	#1, W4		; don't let it go below note 1
	cpslt.b	W4, W10
	mov.b	W4, W10
	mov	#127, W4	; don't let it go above note 127
	cpslt.b	W10, W4
	mov.b	W4, W10	

	; figure out where table would start if it started at zero
	mov	#(key_notes-(2*NOTE_KEY_MIN)), W4
	add	W0, W4, W4	; index into table
	mov	W10, [W4]	; record the note and channel we're playing

	mov	sustain, W4	; get the sustain channel in high byte
	xor	W4, W10, W9	; check against our channel
	clr.b	WREG10H		; we need W10 high byte zero later
	cp0.b	WREG9H		; if channel doesn't match
	bra	nz, 1f		; then definitely not sustaining this note

	; channel matches, check table for whether we're sustaining note
	mov	#sustained_notes, W0
	add	W0, W10, W0
	cp0.b	[W0]
	bra	nz, 2f		; already sustaining this note, skip MIDI

1:
	mov	#0x90, W1	; create "note on" status byte
	ior	W1, W2, W1	; at this point W2 is still channel from above
	mov	velocity, W2	; put velocity in high byte of W2
	sl	W2, #8, W2
	mov.b	W10, W2		; put note number in low byte of W2
	rcall	MIDI_READ_MESSAGE

2:
	btst	sustain, #0	; see if we're sustaining new notes
	bra	z, 1f		; if not then we're done
	cp0.b	WREG9H		; recall whether sustain channel is ours
	bra	nz, 1f		; again, if not then we're done
	
	mov	#sustained_notes, W0	; record fact we're sustaining note
	add	W0, W10, W0
	setm.b	[W0]

1:
	return

note_release:
	; figure out where table would start if it started at zero
	mov	#(key_notes-(2*NOTE_KEY_MIN)), W4
	add	W0, W4, W4	; index into table
	mov	[W4], W10	; get the note and channel we're playing
	ze	W10, W2		; note
	lsr	W10, #8, W0	; channel

	setm	[W4]		; record that we're no longer playing it

	cp0.b	sustain		; see if we're sustaining notes in general
	bra	z, 1f		; if not, then this note must end

	cp.b	sustain_channel	; see if our channel matches sustain channel
	bra	neq, 1f		; if not, then this note must end

	mov	#sustained_notes, W1	; see if this note is sustained
	add	W1, W2, W1
	cp0.b	[W1]
	bra	nz, RETURN_INSN	; if it's being sustained, then don't end it

1:
	; at this point W0 contains the channel in low byte
	; W2 contains note in low byte, zero high byte, from the "ze" above
	mov	#0x90, W1	; create "note on" (actually off) status byte
	ior	W0, W1, W1

	bra	MIDI_READ_MESSAGE	; tail call

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; sustain key (Caps Lock)

	bra	sustain_release	; must be just before sustain_press
sustain_press:
	cp0.b	sustain		; check whether we are locking or unlocking
	bra	nz, unlock_sustain

	inc.b	sustain		; locking, go to state 1

	mov	channel, W0	; find the current channel
	mov.b	WREG, sustain_channel	; store this as sustain channel
	swap	W0		; put channel in high byte of W1
	mov	W0, W1

	; all notes in this channel currently played by keys, will be locked

	mov	#key_notes, W2	; set up for loop
	mov	#sustained_notes, W3

1:
	mov	[W2++], W0	; find the note this key is playing
	xor	W0, W1, W0	; XOR out the channel
	cp0.b	WREG0H		; if it vanishes, we're in the right channel
	bra	nz, 2f		; if it didn't, then skip

	add	W0, W3, W0	; flag this note as locked
	setm.b	[W0]

2:
	; finish loop
	mov	#(key_notes+(NOTE_KEY_MAX-NOTE_KEY_MIN+1)*2), W0
	cp	W2, W0
	bra	ltu, 1b

	return

unlock_sustain:
	clr.b	sustain		; go to state 0
	mov	sustain, W1	; sustain channel remains in high byte

	; for all notes currently played by keys in the sustain channel,
	; clear them from sustained_notes.

	mov	#key_notes, W2	; set up for loop
	mov	#sustained_notes, W3

1:
	mov	[W2++], W0	; find the note this key is playing
	xor	W0, W1, W0	; XOR out the channel
	cp0.b	WREG0H		; if it vanishes, we're in the right channel
	bra	nz, 2f		; if it didn't, then skip

	add	W0, W3, W0	; clear it from sustained_notes
	clr.b	[W0]

2:
	; finish loop
	mov	#(key_notes+(NOTE_KEY_MAX-NOTE_KEY_MIN+1)*2), W0
	cp	W2, W0
	bra	lt, 1b

	; for all notes played by sustain (and not cleared above), send note
	; off messages to the MIDI backend

	clr	W10		; loop counter

1:
	mov	#sustained_notes, W0	; test whether it's being played
	add	W0, W10, W0
	cp0.b	[W0]
	bra	z, 2f

	clr.b	[W0]		; clear the note from sustained_notes

	mov	sustain, W1	; get sustain and sustain channel
	lsr	W1, #8, W1	; channel into low byte
	mov	#0x90, W0	; create "note on" status byte
	ior	W0, W1, W1
	mov	W10, W2		; key number is loop counter, velocity zero
	rcall	MIDI_READ_MESSAGE

2:
	inc	W10, W10	; finish loop
	btst	W10, #7
	bra	z, 1b

	return

sustain_release:
	cp0.b	sustain		; check whether we just unlocked
	bra	z, RETURN_INSN	; if so, nothing more to do

	inc.b	sustain		; else go to state 2

	; return
	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; channel keys (function keys, Esc, PrScr/ScrLock/Pause)

	return			; must be just before channel_press
channel_press:
	mov	#0x3A, W0	; subtract out key code of F1
	sub	W3, W0, W3
	bra	nn, 1f
	mov	#15, W3		; negative result, MIDI channel 16, code 15
1:
	mov	W3, channel	; save result

	; return
	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; isomorphic mode key (Num Lock)

	return			; must be just before iso_mode_press
iso_mode_press:
	btg	leds, #0	; toggle the LED (note keys look at this)
	; return
	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; velocity keys (keypad numerals)

	return			; must be just before velocity_press
velocity_press:
	mov	#0x58, W2	; subtract out key code of keypad 1, minus 1
	sub	W3, W2, W3
	mul.uu	W3, #14, W4	; result could be 14, 28, ..., 126
	mov	W4, velocity	; store it

handle_maintenance_code:
	mov	maintenance_code, W0	; shift this digit into partial code
	sl	W0, #4, W0
	ior	W0, W3, W0
	mov	W0, maintenance_code

	mov	#tbloffset(maint_tbl_start), W1	; loop over code table
1:

	tblrdl	[W1++], W2	; get table entry into W2 and W3
	tblrdl	[W1++], W3

	cpsne	W0, W2		; go do something if code matches
	goto	W3

	mov	#tbloffset(maint_tbl_end), W3	; loop until end of table
	cpseq	W1, W3
	bra	1b

	; return
	; FALL THROUGH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; tap tempo and maintenance code zero (keypad insert)

	return			; must be just before keypad_ins_press
keypad_ins_press:
	rcall	MIDI_TEMPO_TAP
	clr	W3
	bra	handle_maintenance_code

.end
