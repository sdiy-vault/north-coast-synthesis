.psize 44,144
.title "Input and output voltage calibration"
.sbttl "$Id: calibration.s 9758 2022-01-08 17:01:16Z mskala $"
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

; the Makefile chooses a pseudorandom page for us to save calibration data
.include "rndpage.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Calibration page"

; Calibration data lives on a reserved page identified by the __rndpage
; symbol.  It's split into eight "rows" of 64 instruction words each,
; because those are the unit of writing flash memory if we don't go a single
; instruction at a time.  Each time we recalibrate, we write into a fresh
; row until there are none, at which point we erase (returning the page to
; all 0xFF) and start over again.  The last row that isn't all 0xFF is thus
; the most recent, and current, row of calibration data.

; A fresh firmware image comes pre-loaded with estimated calibration data so
; that it'll still be sort of usable even if someone skips the calibration
; procedure.  We fill the page so that on the first real calibration run, it
; will all be automatically erased; that way we avoid any concerns about
; programming rows a second time without an erase that were erased and
; programmed during device load, even if only with 0xFF.

.section calibration, code, address(__rndpage<<8)

; output calibration data:  values to send to the DAC for 0.0V, 0.5V, ...,
; 5.0V output at jack, followed by an 0xFFFF sentinel.  First twelve values
; for channel 1, then twelve for channel 2.  The 0.0V value is always zero.

output_cal1:
	.word 0, 357, 714, 1071, 1429, 1786, 2143, 2500, 2857, 3214, 3571
	.word 0xFFFF
output_cal2:
	.word 0, 357, 714, 1071, 1429, 1786, 2143, 2500, 2857, 3214, 3571
	.word 0xFFFF

; input calibration data:  values expected from ADC for 0.0V, 0.5V, ...,
; 5.0V input at jack, followed by a zero sentinel.  First twelve values for
; channel 1, then twelve for channel 2.  Note there's an inverting amplifier
; between the jack and the microcontroller pin, so these numbers decrease
; for increasing voltage.

; simulation with all components and voltages at their nominal values has
; input of 0V at the external jack giving 3.19V at the microcontroller pin,
; and 5V at the external jack giving 0.665V at the microcontroller pin. 
; These translate to ADC readings of 989 and 206 respectively.  Default
; calibration linearly interpolates between those values.

input_cal1:
	.word 989, 911, 832, 754, 676, 598, 519, 441, 363, 384, 206
	.word 0
input_cal2:
	.word 989, 911, 832, 754, 676, 598, 519, 441, 363, 384, 206
	.word 0

; relocate to end of row (to make sure we haven't overflowed it)
.pfillvalue 0xFF
.porg 0x0080

; fill rest of page with more copies of the data above
.irpc x, 2345678
	.word 0, 357, 714, 1071, 1429, 1786, 2143, 2500, 2857, 3214, 3571
	.word 0xFFFF
	.word 0, 357, 714, 1071, 1429, 1786, 2143, 2500, 2857, 3214, 3571
	.word 0xFFFF
	.word 989, 911, 832, 754, 676, 598, 519, 441, 363, 384, 206
	.word 0
	.word 989, 911, 832, 754, 676, 598, 519, 441, 363, 384, 206
	.word 0
  .porg (\x*0x0080)
.endr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "RAM data structure"

; calibration data is loaded from flash into this RAM data structure, both
; for modifying it during the calibration process, and so that other code
; that uses it doesn't have to dig into the flash

.global OUTPUT_CAL1, OUTPUT_CAL2, INPUT_CAL1, INPUT_CAL2
.section .bss
OUTPUT_CAL1:	.skip 24
OUTPUT_CAL2:	.skip 24
INPUT_CAL1:	.skip 24
INPUT_CAL2:	.skip 24

; time stamps from Timers 4 and 5 of comparator edge events captured by the
; ISR.  These are global in case other code wants to borrow our interrupt
; system.  Comparator 3 is for input jack 1, Comparator 1 is for input jack 2
.global CM3_EDGE_TIME, CM1_EDGE_TIME
CM3_EDGE_TIME:	.skip 2
CM1_EDGE_TIME:	.skip 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "API to the calibration data"

.section .text

; Copy calibration data from flash to RAM; trashes W0 and W1
.global CALIBRATION_TO_RAM
CALIBRATION_TO_RAM:
	mov	#tbloffset(output_cal1+0x400), W0	; last+1 row
1:
	sub	#0x80, W0	; move one row earlier
	tblrdl	[W0], W1	; get first word, should be 0 for valid
	com	W1, W1		; ...or at least not 0xFFFF
	bra	z, 1b		; if row is empty, try earlier row
	; now W0 points at start of most recent valid calibration in flash

	mov	#OUTPUT_CAL1, W1
	repeat	#47
	tblrdl	[W0++], [W1++]

	return

; Get an ADC reading and translate it to a note number in W0, where the high
; byte is the MIDI note number and the low byte is the fractional part.  To
; round this off to a pure MIDI note number, add 0x0080 and then take just
; the high byte of the result.  Use ADC2 or ADC1 entry point as appropriate.
; Trashes W1..W6.
.global ADC1_TO_NOTENUM, ADC2_TO_NOTENUM

ADC2_TO_NOTENUM:
	mov	INPUT_ADC2, W0
	mov	#INPUT_CAL2, W2
	bra	_adc_to_notenum

ADC1_TO_NOTENUM:
	mov	INPUT_ADC1, W0
	mov	#INPUT_CAL1, W2
_adc_to_notenum:
	mov	W2, W3
1:
	cp	W0, [++W2]
	bra	ltu, 1b

	; at this point W3 points to start of calibration table; W2 points
	; to first entry less than or equal to W0, but no earlier than
	; second entry; some such entry exists because table ends with zero. 
	; Therefore we can interpolate.

	mov	[W2], W1	; find step size from low reference
	sub	W0, W1, W0
	mov	#0x600, W6	; scale it to 6 semitones per index
	mul.uu	W0, W6, W4

	mov	[--W2], W0	; find slope of line
	sub	W0, W1, W6
	repeat	#17		; divide to find num semitones below ref
	div.sd	W4, W6

	sub	W2, W3, W1	; calculate reference point from index
	mov	#0x300, W6
	mul.uu	W1, W6, W4

	sub	W4, W0, W0	; subtract the calculated offset
	mov	#0x2A00, W1	; shift for index 0 = note 36
	add	W0, W1, W0
	bclr	W0, #15		; max legal note is 127

	return

; Given a note number in W0, encoded as MIDI number in high byte and
; fraction in low byte, translate that to a DAC value and send to the
; specified DAC.  Use DAC1 or DAC2 entry point as appropriate; these are for
; output channel 1 (hardware DAC B) and output channel 2 (hardware DAC A)
; respectively.
; Trashes W1..W4.
.global	NOTENUM_TO_DAC1, NOTENUM_TO_DAC2

; write W0 to DAC channel; preserves other registers.  The low 12 bits of W0
; are used as the DAC value; any others are truncated.
.global WRITE_DAC1, WRITE_DAC2

NOTENUM_TO_DAC2:
	mov	#OUTPUT_CAL2, W2
	rcall	notenum_to_dacnum
	; tail call:  WRITE_DAC2

; send W0 to DAC for output 2 (which is DAC channel A)
WRITE_DAC2:
	swap	W0		; need to send this in big endian
	and.b	#0xF, W0
	ior	#0x70, W0	; channel A, gain 1, output active
	bra	_write_dac	; after this point code is shared w/ ch. B

NOTENUM_TO_DAC1:
	mov	#OUTPUT_CAL1, W2
	rcall	notenum_to_dacnum
	; tail call:  WRITE_DAC1

; send W0 to DAC for output 1 (which is DAC channel B)
WRITE_DAC1:
	swap	W0		; need to send this in big endian
	ior	#0xF0, W0	; channel B, gain 1, output active

_write_dac:
	bclr	LATA, #1	; start transaction
	mov.b	WREG, SPI1BUF
	swap	W0
	mov.b	WREG, SPI1BUF
1:
	btst	SPI1STAT, #SRXMPT
	bra	nz, 1b
	mov.b	SPI1BUF, WREG
1:
	btst	SPI1STAT, #SRXMPT
	bra	nz, 1b
	mov.b	SPI1BUF, WREG
	bset	LATA, #1	; end transaction
	bclr	LATA, #4	; start strobe
	nop
	bset	LATA, #4	; end strobe
	return

; internals of NOTENUM_TO_DAC{1,2}:  interpolate the note number from W0
; against the table pointed to by W2.
notenum_to_dacnum:

	; We want to map a note and fraction number in W0 to a table index
	; in W0 and remainder in W1 describing how far to interpolate
	; between this table entry and the next one, as follows.  Normally,
	; W1 will be in the range 0x0000-0x05FF.
	;  W0     -->     W0
	; 0x0000-0x29FF   0   note W1 can be negative in this case
	; 0x2A00-0x2FFF   1
	; 0x3000-0x35FF   2
	; 0x3600-0x3BFF   3
	; 0x3C00-0x41FF   4
	; 0x4200-0x47FF   5
	; 0x4800-0x4DFF   6
	; 0x4E00-0x53FF   7
	; 0x5400-0x59FF   8
	; 0x5A00-0x7FFF   9   note W1 can exceed 0x05FF in this case
	; 0x8000-0xFFFF   0   negative inputs go to the index 0 entry

	mov	#0x600, W3	; we need this value later

	; MIDI notes <42 all map into first entry
	mov	#0x2A00, W1
	cp	W0, W1
	bra	ge, 1f		; signed compare here

	mov	#0x2400, W1	; compute remainder for index 0
	sub	W0, W1, W1
	clr	W0
	bra	2f

1:
	; MIDI notes >=90 all map into last entry
	mov	#0x5A00, W1
	cp	W0, W1
	bra	lt, 1f

	sub	W0, W1, W1	; compute remainder for index 9
	mov	#9, W0
	bra	2f
1:
	mov	#0x2400, W1	; do a division to find the table entry
	sub	W0, W1, W4

	repeat	#17
	div.uw	W4, W3

2:
	; at this point W0 identifies the table entry, index into table
	; pointed at by W2.  W1 is the remainder from division, a number
	; normally in [0, 0x600) but possibly out of that range for first
	; or last entry, indicating how far to interpolate between this
	; DAC value (at 0) and the next (at 0x600).

	sl	W0, W0		; find diff between this entry and next
	add	W0, W2, W2
	mov	[W2++], W0
	subr	W0, [W2--], W0

	mul.us	W0, W1, W0	; multiply by the remainder from before
	repeat	#17		; already have 0x600 in W3
	div.sd	W0, W3

	add	W0, [W2], W0	; add the current table entry value as base

	mov	#0x0FFF, W1	; limit result to 0x0000-0x0FFF
	cpslt	W0, W1
	mov	W1, W0
	clr	W1
	cpsgt	W0, W1
	mov	W1, W0

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Common data"

; These variables are only used while calibration is actually in progress,
; so they don't need to be given permanently reserved addresses.

in_common	target_period1, 22
in_common	low_period1, 22
in_common	high_period1, 22

in_common	bad_notes1, 2
in_common	retuned_notes1, 2
in_common	current_note1, 2

in_common	target_period2, 22
in_common	low_period2, 22
in_common	high_period2, 22

in_common	bad_notes2, 2
in_common	retuned_notes2, 2
in_common	current_note2, 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Calibration procedure start"

.pushsection mtbl, code
	; code 5833:  run the calibration procedure
	.word	0x5833, CALIBRATION_PROCEDURE
.popsection

.global CALIBRATION_PROCEDURE
CALIBRATION_PROCEDURE:
	rcall	STANDARD_IO_CONFIG	; analog and GPIO pins
	rcall	USB_DONE		; make sure USB is out of picture

	mov	#0xFF1F, W0		; re-enable interrupts in general
	and	SR

	rcall	LEDBLINK_INIT

	; enable comparator interrupts
	; priority 6 is set in power-on reset
	bset	IEC1, #CMIE

	mov	#tbloffset(channel2_thread), W14	; spawn thread 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Channel 1 thread, output calibration"

; thread 1 is allowed to touch:
; W0, W1 - also available to other thread, so not preserved by yield
; W2..W7 - reserved for this thread, other thread must preserve across yield
; W15 - other thread must preserve across yield

; thread 1 must preserve:
; W8..W13 - reserved for other thread
; W14 - other thread's PC value

	; sanitize the existing calibration data
	mov	#OUTPUT_CAL1, W1
	mov	#0x0FFF, W0
	clr	[W1++]
	repeat	#9
	and	W0, [W1], [W1++]
	setm	[W1]

wait_for_oscillator_1:
	; LED to slow red blink
	clr	LEDBLINK_RB7
	mov	#0xC000, W0
	mov	W0, LEDBLINK_TRIS7	

	; set DAC to 0.0V
	clr	W0
	rcall	WRITE_DAC1

	; T4 prescaler to 1:8, max period, min. measurable frequency 30.52Hz
	setm	PR4
	mov	#0x8010, W0
	mov	W0, T4CON

	; loop:  we need two good-looking timestamp sets in a row
	mov	#2, W3
debounce_loop_1:

; macro:  delay, yielding to other thread, for some number of 65.536 ms ticks
.macro wait_ticks reg, ticks
	mov	\ticks, \reg
7:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_BLINK1
	bra	z, 7b
	bclr	SOFT_INT_FLAGS, #SI_BLINK1
	dec	\reg, \reg
	bra	nz, 7b
.endm

	wait_ticks	W2, #5

	; wait for four timestamps, write them into W4..W7
.ifndef SIMULATE_CALIBRATION_OSC
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W4
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W5
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W6
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W7
.else
	; simulate an oscillator that produces the expected timestamps
	rcall	idle_and_yield
	mov	#30578, W4	; test values for MIDI note 36
	mov	#45867, W5
	mov	#61156, W6
	mov	#10909, W7
.endif

	; compute measured periods from timestamps
	sub	W7, W6, W7
	sub	W6, W5, W6
	sub	W5, W4, W5

	; check each period is in range
	; the magic numbers are 7201 corresponding to 277.724 Hz, which is
	; 513/512 times the frequency of MIDI note 61, and 65408
	; corresponding to 30.577 Hz, which is the longest period such that
	; we can multiply it by 513/512 and still measure the result with
	; our 16-bit counter; also slightly below MIDI note 23.
	mov	#7201, W0
	mov	#65408, W1
	cp	W5, W0
	bra	ltu, wait_for_oscillator_1
	cp	W5, W1
	bra	gtu, wait_for_oscillator_1
	cp	W6, W0
	bra	ltu, wait_for_oscillator_1
	cp	W6, W1
	bra	gtu, wait_for_oscillator_1
	cp	W7, W0
	bra	ltu, wait_for_oscillator_1
	cp	W7, W1
	bra	gtu, wait_for_oscillator_1

	; check period doesn't change much from each to next
	sub	W6, W5, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_1
	neg	W0, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_1
	sub	W7, W6, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_1
	neg	W0, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_1

	; periods look reasonable, finish the debounce loop
	dec	W3, W3
	bra	nz, debounce_loop_1

	; calculate target periods and limits
	rcall	idle_and_yield
	mov	#target_period1, W1
	mov	W7, [W1]
	rcall	calculate_targets

	; adjustment size in W2, 256 down to 1
	mov	#0x0100, W2

output_allnotes_loop_1:
	; RAM variables for detecting loop completion
	clr	bad_notes1
	clr	retuned_notes1
	clr	current_note1
	inc2	current_note1	; starts at note 1, address 2

output_note_loop_1:
	; get current calibration value
	mov	current_note1, W4
	mov	#OUTPUT_CAL1, W1
	add	W4, W1, W1

	; send current value to DAC
	mov	[W1], W0
	rcall	WRITE_DAC1

	; set T4 prescaler to 1:8 for notes 0..5, 1:1 for notes 6..10
	mov	#0x8010, W0	; prescaler to 1:8, timer on
	cp	W4, #12		; is byte count, so this means note 6
	bra	ltu, 1f
	bclr	W0, #4		; change prescale to 1:1
1:
	mov	W0, T4CON

	wait_ticks	W3, #5	; wait for VCO to stabilize

	; wait for four timestamps, write them into W4..W7
.ifndef SIMULATE_CALIBRATION_OSC
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W4
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W5
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W6
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W7
.else
	; simulate an oscillator that produces the expected timestamps
	rcall	idle_and_yield
	mov	current_note1, W0
	mov	#target_period1, W1
	add	W0, W1, W1
	mov	[W1], W1
	mov	#0xFF00, W4
	add	W4, W1, W5
	add	W5, W1, W6
	add	W6, W1, W7
.endif

	; compute measured periods from timestamps
	sub	W7, W6, W7
	sub	W6, W5, W6
	sub	W5, W4, W5

	; compute differences between successive periods
	sub	W5, W6, W3
	sub	W6, W7, W4

	; test:  are the periods consistent?
	cp	W3, #OUTPUT_CAL_FUZZ
	bra	gt, 1f
	neg	W3, W3
	cp	W3, #OUTPUT_CAL_FUZZ
	bra	gt, 1f
	cp	W4, #OUTPUT_CAL_FUZZ
	bra	gt, 1f
	neg	W4, W4
	cp	W4, #OUTPUT_CAL_FUZZ
	bra	le, 2f
1:
	inc	bad_notes1	; not consistent, keep trying this step size
	bra	output_note_increment_1
2:

	; test most recent period against lower limit
	mov	current_note1, W3
	mov	#low_period1, W1
	add	W3, W1, W1
	cp	W7, [W1]
	bra	geu, 1f

	; it's too low, adjust calibration value
	inc	retuned_notes1
	mov	#OUTPUT_CAL1, W4
	add	W3, W4, W4
	subr	W2, [W4], W0

	; check against next lower calibration value
	mov	[W4-2], W5
	cp	W0, W5
	bra	gtu, 2f
	inc	W5, W0	; enforce W5<W0
2:
	mov	#0x0FFF, W1	; enforce 12-bit value
	and	W0, W1, W0
	mov	W0, [W4]	; save the adjusted calibration value
	bra	output_note_increment_1	; skip the upper limit test
1:

	; test most recent period against upper limit
	mov	#high_period1, W1
	add	W3, W1, W1
	cp	W7, [W1]
	bra	leu, 1f

	; it's too high, adjust calibration value
	inc	retuned_notes1
	mov	#OUTPUT_CAL1, W4
	add	W3, W4, W4
	add	W2, [W4], W0

	; check against next higher calibration value
	mov	[W4+2], W5
	cp	W0, W5
	bra	ltu, 2f
	dec	W5, W0	; enforce W5>W0
2:
	mov	#0x0FFF, W1	; enforce 12-bit value
	and	W0, W1, W0
	mov	W0, [W4]	; save the adjusted calibration value
1:

output_note_increment_1:
	inc2	current_note1
	mov	current_note1, W0
	cp	W0, #22
	bra	ltu, output_note_loop_1

	; make sure note 0 is still on its target
	
	; set DAC to 0.0V
	clr	W0
	rcall	WRITE_DAC1

	; T4 prescaler to 1:8, min. measurable frequency 30.52Hz
	mov	#0x8010, W0
	mov	W0, T4CON

	wait_ticks	W3, #5

	; wait for four timestamps, write them into W4..W7
.ifndef SIMULATE_CALIBRATION_OSC
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W4
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W5
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W6
	bclr	SOFT_INT_FLAGS, #SI_CM3
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_CM3
	bra	z, 1b
	mov	CM3_EDGE_TIME, W7
.else
	; simulate an oscillator that produces the expected timestamps
	rcall	idle_and_yield
	mov	target_period1, W1
	mov	#0xFF00, W4
	add	W4, W1, W5
	add	W5, W1, W6
	add	W6, W1, W7
.endif

	; compute measured periods from timestamps
	sub	W7, W6, W7
	sub	W6, W5, W6
	sub	W5, W4, W5

	; compute differences between successive periods
	sub	W5, W6, W3
	sub	W6, W7, W4

	; test:  are the periods consistent?
	cp	W3, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_1
	neg	W3, W3
	cp	W3, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_1

	; test most recent period against lower limit
	mov	#low_period1, W1
	cp	W7, [W1]
	bra	ltu, wait_for_oscillator_1

	; test most recent period against upper limit
	mov	#high_period1, W1
	cp	W7, [W1]
	bra	gtu, wait_for_oscillator_1

	; set new blink pattern
	mov	bad_notes1, W0
	add	retuned_notes1, WREG
	mov	#4, W1
	sl	W1, W0, W1
	dec	W1, W1
	com	W1, W1
	mov	W1, LEDBLINK_TRIS7

	; if no bad notes, take smaller steps
	cp0	bad_notes1
	bra	nz, 1f
	mov	W2, W1
	lsr	W2, W2
	add	W1, W2, W2
	lsr	W2, W2
	bra	nz, 1f
	inc	W2, W2
1:

	; if still some retuning or bad notes, do another cycle
	cp0	W0
	bra	gtu, output_allnotes_loop_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Channel 1 thread, input calibration"

	; LED to medium red/green blink
	mov	#0x00FF, W0
	mov	W0, LEDBLINK_RB7
	mov	#0x8080, W0
	mov	W0, LEDBLINK_TRIS7	

input_allnotes_loop_1:
	clr	W2	; bad notes
	clr	W3	; current note

input_note_loop_1:
	; send this note's output value to the DAC
	mov	#OUTPUT_CAL1, W0
	add	W3, W0, W0
	mov	[W0], W0
	rcall	WRITE_DAC1

	; wait for voltage to stabilize
	wait_ticks	W4, #2

	; W0 is reading, W4 loop counter, W5 min, W6 max, W7 total

	; loop over 16 measurements
	mov	#16, W4
	mov	#0x3FF, W5
	clr	W6
	clr	W7
2:

	; get one ADC reading
.ifndef SIMULATE_CALIBRATION_ADC
	bclr	SOFT_INT_FLAGS, #SI_ADC1
1:
	rcall	idle_and_yield
	btst	SOFT_INT_FLAGS, #SI_ADC1
	bra	z, 1b
	mov	INPUT_ADC1, W0
	bclr	SOFT_INT_FLAGS, #SI_ADC1
.else
	rcall	idle_and_yield
	; make up plausible simulated reading
	sl	W3, #5, W1
	mov	#830, W0
	sub	W0, W1, W0
.endif

	cpsgt	W0, W5		; update min
	mov	W0, W5

	cpslt	W0, W6		; update max
	mov	W0, W6

	sub	W6, W5, W1	; check range
	cp	W1, #INPUT_CAL_FUZZ
	bra	gt, input_note_bad_1

	add	W0, W7, W7	; update total

	dec	W4, W4		; loop for another measurement
	bra	nz, 2b

	asr	W7, #4, W7	; mean of 16 measurements into W7

	; find address of previous note's input calibration data
	mov	#(INPUT_CAL1-2), W1
	add	W1, W3, W1

	; input calibration values must be strictly decreasing
	cp0	W3
	bra	z, 1f
	cp	W7, [W1]
	bra	geu, input_note_bad_1
	bra	2f

1:
	; at this point we know we're on note 0
	; spot-check calibration value is within 1.5V of nominal
	mov	#754, W0
	cp	W7, W0
	bra	ltu, input_note_bad_1
2:

	; similarly, note 10 within 1.5V of nominal
	cp	W3, #20
	bra	nz, input_note_save_1
	mov	#441, W0
	cp	W7, W0
	bra	gtu, input_note_bad_1

input_note_save_1:
	mov	W7, [++W1]	; save new calibration value
	bra	input_note_increment_1

input_note_bad_1:
	inc	W2, W2		; this note is bad

input_note_increment_1:
	; loop over all 11 notes
	inc2	W3, W3
	cp	W3, #22
	bra	nz, input_note_loop_1

	; compute the new blink pattern
	; this loop takes W0 through the numbers 0, 8, 1, 9, 2, 10, ...
	; which are the order of turning on bits in W4 to create the pattern
	clr	W3	; loop counter, 0..15
	clr	W4	; pattern we're building
	inc2	W2, W5	; number of 1s to put in output = bad notes + 2
1:
	lsr	W3, W0	; rotate bit 0 into bit 3
	bra	nc, 2f
	bset	W0, #3
2:
	inc	W3, W3	; bump loop counter, w/ side effect clear zero flag
	bsw.z	W4, W0	; set bit corresponding to W0
	cp	W3, W5
	bra	ltu, 1b
	com	W4, W4
	mov	W4, LEDBLINK_TRIS7

	; loop until no bad notes
	cp0	W2
	bra	nz, input_allnotes_loop_1

	; sanitize result
	mov	#INPUT_CAL1, W1
	mov	#0x03FF, W0
	repeat	#10
	and	W0, [W1], [W1++]
	clr	[W1]

	; LED to fast green blink
	setm	LEDBLINK_RB7
	mov	#0xCCCC, W0
	mov	W0, LEDBLINK_TRIS7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Calibration procedure end"

.ifdef SEQUENTIAL_CALIBRATION
	rcall	channel2_thread
.else
	; join with thread 2
1:
	rcall	idle_and_yield
	mov	#tbloffset(channel2_thread_end), W0
	cp	W0, W14
	bra	nz, 1b
.endif

	bset	IEC1, #CMIE	; disable comparator interrupt

	rcall	CALIBRATION_TO_FLASH
	rcall	LEDBLINK_DONE
	bra	SUCCESS_TUNE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Channel 2 thread, output calibration"

; thread 2 is allowed to touch:
; W0, W1 - also available to other thread, so not preserved by yield
; W8..13 - reserved for this thread, other thread must preserve across yield

; thread 2 must preserve:
; W2..W7 - reserved for other thread
; W14 - other thread's PC value
; W15 - stack pointer

channel2_thread:
	; sanitize the existing calibration data
	mov	#OUTPUT_CAL2, W1
	mov	#0x0FFF, W0
	clr	[W1++]
	repeat	#9
	and	W0, [W1], [W1++]
	setm	[W1]

wait_for_oscillator_2:
	; LED to slow red blink
	clr	LEDBLINK_RB9
	mov	#0xC000, W0
	mov	W0, LEDBLINK_TRIS9

	; set DAC to 0.0V
	clr	W0
	rcall	WRITE_DAC2

	; T5 prescaler to 1:8, max period, min. measurable frequency 30.52Hz
	setm	PR5
	mov	#0x8010, W0
	mov	W0, T5CON

	; loop:  we need two good-looking timestamp sets in a row
	mov	#2, W9
debounce_loop_2:

; macro redefined b/c thread 2 uses a different flag and doesn't idle the CPU
.purgem wait_ticks
.macro wait_ticks reg, ticks
	mov	\ticks, \reg
7:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_BLINK2
	bra	z, 7b
	bclr	SOFT_INT_FLAGS, #SI_BLINK2
	dec	\reg, \reg
	bra	nz, 7b
.endm

	wait_ticks	W8, #5

	; wait for four timestamps, write them into W10..W13
.ifndef SIMULATE_CALIBRATION_OSC
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W10
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W11
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W12
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W13
.else
	; simulate an oscillator that produces the expected timestamps
	rcall	yield
	mov	#30578, W10	; test values for MIDI note 36
	mov	#45867, W11
	mov	#61156, W12
	mov	#10909, W13
.endif

	; compute measured periods from timestamps
	sub	W13, W12, W13
	sub	W12, W11, W12
	sub	W11, W10, W11

	; check each period is in range
	; the magic numbers are 7201 corresponding to 277.724 Hz, which is
	; 513/512 times the frequency of MIDI note 61, and 65408
	; corresponding to 30.577 Hz, which is the longest period such that
	; we can multiply it by 513/512 and still measure the result with
	; our 16-bit counter; also slightly below MIDI note 23.
	mov	#7201, W0
	mov	#65408, W1
	cp	W11, W0
	bra	ltu, wait_for_oscillator_2
	cp	W11, W1
	bra	gtu, wait_for_oscillator_2
	cp	W12, W0
	bra	ltu, wait_for_oscillator_2
	cp	W12, W1
	bra	gtu, wait_for_oscillator_2
	cp	W13, W0
	bra	ltu, wait_for_oscillator_2
	cp	W13, W1
	bra	gtu, wait_for_oscillator_2

	; check period doesn't change much from each to next
	sub	W12, W11, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_2
	neg	W0, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_2
	sub	W13, W12, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_2
	neg	W0, W0
	cp	W0, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_2

	; periods look reasonable, finish the debounce loop
	dec	W9, W9
	bra	nz, debounce_loop_2

	; calculate target periods and limits
	rcall	yield
	mov	#target_period2, W1
	mov	W13, [W1]
	rcall	calculate_targets

	; adjustment size in W8, 256 down to 1
	mov	#0x0100, W8

output_allnotes_loop_2:
	; RAM variables for detecting loop completion
	clr	bad_notes2
	clr	retuned_notes2
	clr	current_note2
	inc2	current_note2	; starts at note 1, address 2

output_note_loop_2:
	; get current calibration value
	mov	current_note2, W10
	mov	#OUTPUT_CAL2, W1
	add	W10, W1, W1

	; send current value to DAC
	mov	[W1], W0
	rcall	WRITE_DAC2

	; set T5 prescaler to 1:8 for notes 0..5, 1:1 for notes 6..10
	mov	#0x8010, W0	; prescaler to 1:8, timer on
	cp	W10, #12	; is byte count, so this means note 6
	bra	ltu, 1f
	bclr	W0, #4		; change prescale to 1:1
1:
	mov	W0, T5CON

	wait_ticks	W9, #5	; wait for VCO to stabilize

	; wait for four timestamps, write them into W10..W13
.ifndef SIMULATE_CALIBRATION_OSC
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W10
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W11
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W12
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W13
.else
	; simulate an oscillator that produces the expected timestamps
	rcall	yield
	mov	current_note2, W0
	mov	#target_period2, W1
	add	W0, W1, W1
	mov	[W1], W1
	mov	#0xFF00, W10
	add	W10, W1, W11
	add	W11, W1, W12
	add	W12, W1, W13
.endif

	; compute measured periods from timestamps
	sub	W13, W12, W13
	sub	W12, W11, W12
	sub	W11, W10, W11

	; compute differences between successive periods
	sub	W11, W12, W9
	sub	W12, W13, W10

	; test:  are the periods consistent?
	cp	W9, #OUTPUT_CAL_FUZZ
	bra	gt, 1f
	neg	W9, W9
	cp	W9, #OUTPUT_CAL_FUZZ
	bra	gt, 1f
	cp	W10, #OUTPUT_CAL_FUZZ
	bra	gt, 1f
	neg	W10, W10
	cp	W10, #OUTPUT_CAL_FUZZ
	bra	le, 2f
1:
	inc	bad_notes2	; not consistent, keep trying this step size
	bra	output_note_increment_2
2:

	; test most recent period against lower limit
	mov	current_note2, W9
	mov	#low_period2, W1
	add	W9, W1, W1
	cp	W13, [W1]
	bra	geu, 1f

	; it's too low, adjust calibration value
	inc	retuned_notes2
	mov	#OUTPUT_CAL2, W10
	add	W9, W10, W10
	subr	W8, [W10], W0

	; check against next lower calibration value
	mov	[W10-2], W11
	cp	W0, W11
	bra	gtu, 2f
	inc	W11, W0	; enforce W11<W0
2:
	mov	#0x0FFF, W1	; enforce 12-bit value
	and	W0, W1, W0
	mov	W0, [W10]	; save the adjusted calibration value
	bra	output_note_increment_2	; skip the upper limit test
1:

	; test most recent period against upper limit
	mov	#high_period2, W1
	add	W9, W1, W1
	cp	W13, [W1]
	bra	leu, 1f

	; it's too high, adjust calibration value
	inc	retuned_notes2
	mov	#OUTPUT_CAL2, W10
	add	W9, W10, W10
	add	W8, [W10], W0

	; check against next higher calibration value
	mov	[W10+2], W11
	cp	W0, W11
	bra	ltu, 2f
	dec	W11, W0	; enforce W11>W0
2:
	mov	#0x0FFF, W1	; enforce 12-bit value
	and	W0, W1, W0
	mov	W0, [W10]	; save the adjusted calibration value
1:

output_note_increment_2:
	inc2	current_note2
	mov	current_note2, W0
	cp	W0, #22
	bra	ltu, output_note_loop_2

	; make sure note 0 is still on its target
	
	; set DAC to 0.0V
	clr	W0
	rcall	WRITE_DAC2

	; T5 prescaler to 1:8, min. measurable frequency 30.52Hz
	mov	#0x8010, W0
	mov	W0, T5CON

	wait_ticks	W9, #5

	; wait for four timestamps, write them into W10..W13
.ifndef SIMULATE_CALIBRATION_OSC
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W10
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W11
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W12
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_CM1
	bra	z, 1b
	mov	CM1_EDGE_TIME, W13
.else
	; simulate an oscillator that produces the expected timestamps
	rcall	yield
	mov	target_period2, W1
	mov	#0xFF00, W10
	add	W10, W1, W11
	add	W11, W1, W12
	add	W12, W1, W13
.endif

	; compute measured periods from timestamps
	sub	W13, W12, W13
	sub	W12, W11, W12
	sub	W11, W10, W11

	; compute differences between successive periods
	sub	W11, W12, W9
	sub	W12, W13, W10

	; test:  are the periods consistent?
	cp	W9, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_2
	neg	W9, W9
	cp	W9, #OUTPUT_CAL_FUZZ
	bra	gt, wait_for_oscillator_2

	; test most recent period against lower limit
	mov	#low_period2, W1
	cp	W13, [W1]
	bra	ltu, wait_for_oscillator_2

	; test most recent period against upper limit
	mov	#high_period2, W1
	cp	W13, [W1]
	bra	gtu, wait_for_oscillator_2

	; set new blink pattern
	mov	bad_notes2, W0
	add	retuned_notes2, WREG
	mov	#4, W1
	sl	W1, W0, W1
	dec	W1, W1
	com	W1, W1
	mov	W1, LEDBLINK_TRIS9

	; if no bad notes, take smaller steps
	cp0	bad_notes2
	bra	nz, 1f
	mov	W8, W1
	lsr	W8, W8
	add	W1, W8, W8
	lsr	W8, W8
	bra	nz, 1f
	inc	W8, W8
1:

	; if still some retuning or bad notes, do another cycle
	cp0	W0
	bra	gtu, output_allnotes_loop_2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Channel 2 thread, input calibration"

	; LED to medium red/green blink
	mov	#0x00FF, W0
	mov	W0, LEDBLINK_RB9
	mov	#0x8080, W0
	mov	W0, LEDBLINK_TRIS9

input_allnotes_loop_2:
	clr	W8	; bad notes
	clr	W9	; current note

input_note_loop_2:
	; send this note's output value to the DAC
	mov	#OUTPUT_CAL2, W0
	add	W9, W0, W0
	mov	[W0], W0
	rcall	WRITE_DAC2

	; wait for voltage to stabilize
	wait_ticks	W10, #2

	; W0 is reading, W10 loop counter, W11 min, W12 max, W13 total

	; loop over 16 measurements
	mov	#16, W10
	mov	#0x3FF, W11
	clr	W12
	clr	W13
2:

	; get one ADC reading
.ifndef SIMULATE_CALIBRATION_ADC
	bclr	SOFT_INT_FLAGS, #SI_ADC2
1:
	rcall	yield
	btst	SOFT_INT_FLAGS, #SI_ADC2
	bra	z, 1b
	mov	INPUT_ADC2, W0
	bclr	SOFT_INT_FLAGS, #SI_ADC2
.else
	rcall	yield
	; make up plausible simulated reading
	sl	W9, #5, W1
	mov	#830, W0
	sub	W0, W1, W0
.endif

	cpsgt	W0, W11		; update min
	mov	W0, W11

	cpslt	W0, W12		; update max
	mov	W0, W12

	sub	W12, W11, W1	; check range
	cp	W1, #INPUT_CAL_FUZZ
	bra	gt, input_note_bad_2

	add	W0, W13, W13	; update total

	dec	W10, W10	; loop for another measurement
	bra	nz, 2b

	asr	W13, #4, W13	; mean of 16 measurements into W13

	; find address of previous note's input calibration data
	mov	#(INPUT_CAL2-2), W1
	add	W1, W9, W1

	; input calibration values must be strictly decreasing
	cp0	W9
	bra	z, 1f
	cp	W13, [W1]
	bra	geu, input_note_bad_2
	bra	2f

1:
	; at this point we know we're on note 0
	; spot-check its calibration value is within 1.5V of nominal
	mov	#754, W0
	cp	W13, W0
	bra	ltu, input_note_bad_2
2:

	; similarly, note 10 within 1.5V of nominal
	cp	W9, #20
	bra	nz, input_note_save_2
	mov	#441, W0
	cp	W13, W0
	bra	gtu, input_note_bad_2

input_note_save_2:
	mov	W13, [++W1]	; save new calibration value
	bra	input_note_increment_2

input_note_bad_2:
	inc	W8, W8	; this note is bad

input_note_increment_2:
	; loop over all 11 notes
	inc2	W9, W9
	cp	W9, #22
	bra	nz, input_note_loop_2

	; compute the new blink pattern
	; this loop takes W0 through the numbers 0, 8, 1, 9, 2, 10, ...
	; which are the order of turning on bits in W10 to create the pattern
	clr	W9	; loop counter, 0..15
	clr	W10	; pattern we're building
	inc2	W8, W11	; number of 1s to put in output = bad notes + 2
1:
	lsr	W9, W0	; rotate bit 0 into bit 3
	bra	nc, 2f
	bset	W0, #3
2:
	inc	W9, W9	; bump loop counter, w/ side effect clear zero flag
	bsw.z	W10, W0	; set bit corresponding to W0
	cp	W9, W11
	bra	ltu, 1b
	com	W10, W10
	mov	W10, LEDBLINK_TRIS9

	; loop until no bad notes
	cp0	W8
	bra	nz, input_allnotes_loop_2

	; sanitize result
	mov	#INPUT_CAL2, W1
	mov	#0x03FF, W0
	repeat	#10
	and	W0, [W1], [W1++]
	clr	[W1]

	; LED to fast green blink
	setm	LEDBLINK_RB9
	mov	#0xCCCC, W0
	mov	W0, LEDBLINK_TRIS9

	; await death
1:
	rcall	yield
channel2_thread_end:
.ifdef SEQUENTIAL_CALIBRATION
	return
.else
	bra	1b
.endif


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Subroutines"

; stub versions for testing - no actual context switch
.ifdef SEQUENTIAL_CALIBRATION
idle_and_yield:
yield:
	pwrsav #1
	return

.else
; called (only from thread 1 because of its effect on stack) to wait for
; interrupt while giving the other thread a chance before and after
idle_and_yield:
	rcall	yield
	pwrsav	#1
	; tail call to plain yield

; called to switch threads
yield:
	pop	W0
	pop	W0
	exch	W0, W14
	goto	W0
.endif

; given W1 pointer to start of the target-period data structure, with the
; first field filled in with the target period for note 0, fill in the rest
; of the data structure.  Called from both threads, must preserve W2..W15.
calculate_targets:
	push	W2
	push	W3
	mov	W1, W3

	mov	[W3], W0	; get period for note 0
	mov	W0, [W3+12]	; this is period for note 6

	lsr	W0, W1		; divide by 2
	mov	W1, [W3+4]	; this is period for note 2
	mov	W1, [W3+16]	; also note 8

	lsr	W1, W1		; divide by 2
	mov	W1, [W3+8]	; this is period for note 4
	mov	W1, [W3+20]	; also note 10

	; 33461/47321 is the best approximation to 1/sqrt(2) with numerator
	; and denominator fitting in unsigned 16-bit integers; see OEIS
	; sequence number A001333

	mov	#33461, W1	; numerator
	mul.uu	W0, W1, W0	; multiply with result into W1:W0
	mov	#47321, W2	; denominator
	repeat	#17		; do the division
	div.ud	W0, W2

	mov	W0, [W3+2]	; result of division is period for note 1
	mov	W0, [W3+14]	; also period for note 7

	lsr	W0, W1		; divide by 2
	mov	W1, [W3+6]	; this is period for note 3
	mov	W1, [W3+18]	; also note 9

	lsr	W1, W1		; divide by 2
	mov	W1, [W3+10]	; this is period for note 5

	mov	#11, W2		; now loop over all notes
1:
	mov	[W3++], W0	; get target period
	lsr	W0, #9, W1	; fuzz is 1/512 of period
	sub	W0, W1, W0	; compute lower limit
	mov	W0, [W3+20]	; write lower limit taking into account ++
	add	W0, W1, W0	; compute upper limit
	add	W0, W1, W0
	mov	W0, [W3+42]	; write upper limit
	dec	W2, W2		; finish loop
	bra	nz, 1b

	pop	W3
	pop	W2
	return

; write the RAM calibration data to flash
.global CALIBRATION_TO_FLASH
CALIBRATION_TO_FLASH:
	clrwdt

	; is there an unused row on the calibration page?
	mov	#tbloffset(output_cal1+0x380), W2
	tblrdl	[W2], W1
	com	W1, W1
	bra	z, find_empty_row

	; no unused row; must erase page
	mov	#0x4042, W0	; select flash page erase mode
	mov	W0, NVMCON
	mov	#tbloffset(output_cal1), W1
	tblwtl	W1, [W1]	; one write to establish target address

	rcall	PERFORM_FLASH_OPERATION

	; search for a row that starts with 0xFFFF (must exist by above)
find_empty_row:
	mov	#tbloffset(output_cal1-0x80), W1
	mov	#0x80, W2
1:
	add	W1, W2, W1
	tblrdl	[W1], W0
	com	W0, W0
	bra	nz, 1b

	mov	#0x4001, W0	; select row write
	mov	W0, NVMCON

	; copy over the RAM calibration data to program latches
	clr	W0
	mov	#OUTPUT_CAL1, W2
	mov	#(OUTPUT_CAL1+0x60), W3
1:
	tblwtl	[W2++], [W1]
	tblwth	W0, [W1++]
	cp	W2, W3
	bra	nz, 1b

	; fill remaining program latches with 0xFFFF
	setm	W0
	mov	#0x20, W3
1:
	tblwtl	W0, [W1]
	tblwth	W0, [W1++]
	dec2	W3, W3
	bra	nz, 1b

	bra	PERFORM_FLASH_OPERATION	; tail call

; comparator interrupt; save timestamps for comparators that have triggered
.section .isr, code
.global __CompInterrupt
__CompInterrupt:
	push	W0		; save registers
	push	W1

	mov	TMR4, W0	; get timestamps unconditionally
	mov	TMR5, W1
	bclr	IFS1, #CMIF	; acknowledge interrupt

	; Workaround for hardware issue:  sometimes the hardware flags a
	; comparator event on the falling edge even though we only asked for
	; notification on rising edges.  Not clear whether this may be
	; associated with the published silicon erratum for the comparators,
	; is an unpublished erratum, or is some kind of noise or bounce in
	; our external circuitry and not the comparator's fault.  Leaving
	; that unknown, we check the comparator output and ignore the
	; interrupt if the level is not high indicating a rising edge.

	btst	CM3CON, #CEVT	; check for Comparator 3 (DIN1) event
	bra	z, 1f
	bclr	CM3CON, #CEVT
	btst	CM3CON, #COUT	; check for rising edge
	bra	z, 1f
	mov	W0, CM3_EDGE_TIME
	bset	SOFT_INT_FLAGS, #SI_CM3
1:

	btst	CM1CON, #CEVT	; check for Comparator 1 (DIN2) event
	bra	z, RETFIE_W0_1
	bclr	CM1CON, #CEVT
	btst	CM1CON, #COUT	; check for rising edge
	bra	z, RETFIE_W0_1
	mov	W1, CM1_EDGE_TIME
	bset	SOFT_INT_FLAGS, #SI_CM1

	bra	RETFIE_W0_1	; restore registers and return

.end
