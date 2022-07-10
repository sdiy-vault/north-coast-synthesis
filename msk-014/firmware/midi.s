.psize 44,144
.title "MIDI back end"
.sbttl "$Id: midi.s 9811 2022-02-03 00:20:26Z mskala $"
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

.section .bss

start_clear:

; current "running status" byte, or zero if none
running_status:	.skip 2

; buffer for data bytes being accumulated by MIDI_READ_BYTE
streamed_bytes:	.skip 2

; the TEMPO_CLOCK variable counts MIDI clocks, which are associated with
; overflows of T4/5.  Beats occur when TEMPO_CLOCK hits a multiple of 24.
; ISR takes it through the values 0..71, 48..71, 48..71, ... (resetting to
; 48 when it would hit 72); tap tempo resets it to 0.
.global TEMPO_CLOCK
TEMPO_CLOCK:	.skip 2

; Keep track of milliseconds since start of beat; high byte counts down from
; 80, bottom bit of low byte is 1 as long as that's nonzero.  We use this
; in the QWERTY driver and Channel 12 to flash an LED at the start of each
; beat.  Soft counter instead of digging into TEMPO_CLOCK and Timer 4/5
; because this is easier to keep correct in external-clock situations.
.global BEAT_FLASH
BEAT_FLASH:	.skip 2 

; current state of Peripheral Pin Select for output jacks.  Bits 0 and 1 of
; each byte indicate current mapping of left (high byte) and right (low
; byte) digital output jacks.  These assignments mean we can easily test
; each condition we want to test, and initializing to zero puts us in the
; safe state of mapping unknown.
;   000000.. 000000..  unused bits should remain zero
;   ........ ......00  right jack/RP8 state unknown
;   ........ ......01  right jack/RP8 not mapped, GPIO RB8
;   ........ ......10  right jack/RP8 mapped to OC2, 960us pulse
;   ........ ......11  right jack/RP8 mapped to OC2, square wave
;   ......00 ........  left jack/RP14 state unknown
;   ......01 ........  left jack/RP14 not mapped, GPIO RB14
;   ......10 ........  left jack/RP14 mapped to OC1, 960us pulse
;   ......11 ........  left jack/RP14 mapped to OC1, square wave (not used)
pps_status:	.skip 2

; flags to request that the background processing do things
.equ BF_EAT_1MS, 0	; eat an SI_1MS even before doing flags 1 or 2
.equ BF_RAISE_GATE1, 1	; on next SI_1MS, raise gate 1
.equ BF_RAISE_GATE2, 2	; on next SI_1MS, raise gate 2
.equ BF_RAISE_CV2, 4	; on next SI_1MS, raise CV2
background_flags:	.skip 2

; record most recent channel in which we've heard a "note on", as MIDI
; message bits (so e.g. Channel 1 gives this variable the value 0)
recent_channel:	.skip 2

; next three variables are duplicated for channels with low bit clear (1, 3,
; 5, ...) and channels with low bit set (2, 4, 6, ...).

; mono_data is note and velocity of the currently playing note
; pitch_bend_amt is shifted to the 16-bit signed numbers -8192 to +8191
; pitch_bend_range is on a scale where 0x0200 (the default) is +-200 cents
; but note low byte units are 1/256 of the high byte, not raw cents per MIDI
.equ MD_BLOCK_SIZE, 6
mono_data:		.skip 2
pitch_bend_amt:		.skip 2
pitch_bend_range:	.skip 2
			.skip MD_BLOCK_SIZE	; duplicates

; record the value of TEMPO_CLOCK at which we last sent a clock/reset pulse,
; or selected a note for arpeggiation
pulsed_tick:	.skip 2

; record (in low four bits) which drum notes are currently active
drum_notes:	.skip 2

; bit array representing which notes are currently held, for the quantizer
; channels.  Organized as one word per octave, bit 0 to 11 in the word for
; the notes of that octave.  MIDI notes 0-127 require 11 words.
quant_notes:	.skip 22

; previous quantized note numbers, for sending a pulse when they change
quant_previous:	.skip 4

; count of held notes for the arpeggiator
arp_note_count:	.skip 2

; array of notes currently held, for the arpeggiator
arp_notes:	.skip 128

; index of where we are in arpeggiating arp_notes; high byte left,
; low byte right.
arp_index:	.skip 2

; data bytes for duophonic mode:  first word right, second word left
duo_data:	.skip 4

; nonzero if left note is most recent note
duo_side:	.skip 2

end_clear:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "MIDI driver init"

.section .text

; initialize the MIDI subsystem
; trashes W0 and  W4
.global MIDI_INIT
MIDI_INIT:
	mov	#0x8018, W0	; T4/5 on, 32-bit mode, 1:8 prescale
	mov	W0, T4CON
	setm	PR5		; 35.8 minute clock, 14.3 hour beat
	setm	PR4
	clr	TMR5HLD		; start at zero
	clr	TMR4

	mov	#OC3CON1, W4	; configure OC3 and OC4 to generate pulses
	rcall	config_oc_pulse
	inc2	W4, W4
	rcall	config_oc_pulse

	bclr	IFS1, #OC3IF	; clear current interrupts from OC3 and OC4
	bclr	IFS1, #OC4IF

	bset	IEC1, #OC3IE	; request future interrupts from OC3 and OC4
	bset	IEC1, #OC4IE

	mov	#48, W0		; start with no history of tap tempo
	mov	W0, TEMPO_CLOCK

	mov	#start_clear, W0	; clear RAM data
	repeat	#(((end_clear-start_clear)/2)-1)
	clr	[W0++]

	bset	pitch_bend_range, #9	; default +-2 semitones
	bset	pitch_bend_range+MD_BLOCK_SIZE, #9

	bclr	IFS1, #T5IF	; start the tempo clock
	bset	IEC1, #T5IE

	bra	START_CRC	; tail call

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Background processing"

; do any recurring tasks that the MIDI subsystem needs
; trashes W0-W7
.global MIDI_BACKGROUND
MIDI_BACKGROUND:
	btst	SOFT_INT_FLAGS, #SI_1MS	; check for millisecond event
	bra	z, 1f

	btst	background_flags, #BF_EAT_1MS	; check for eating a tick
	bra	nz, 2f

	btsc	background_flags, #BF_RAISE_GATE1	; handle gate 1
	bset	LATB, #14

	btsc	background_flags, #BF_RAISE_GATE2	; handle gate 2
	bset	LATB, #8

	btst	background_flags, #BF_RAISE_CV2	; handle CV2
	bra	z, 3f
	mov	#0x0FFF, W0
	rcall	WRITE_DAC2
3:

	; maintain the BEAT_FLASH variable
	clr.b	BEAT_FLASH
	cp0.b	BEAT_FLASH+1
	bra	z, 3f
	dec.b	BEAT_FLASH+1
	bra	z, 3f
	bset	BEAT_FLASH, #0
3:

	; clear flags here, before the per-channel background, in case it
	; wants to set them again
	clr	background_flags
	rcall	per_channel_background

	; end of once-per-millisecond stuff

2:
	bclr	SOFT_INT_FLAGS, #SI_1MS
	bclr	background_flags, #BF_EAT_1MS
1:

	; prevent tempo clock advancing when it's supposed to be stopped

	inc	PR5, WREG	; check whether we are at max tempo period
	bra	nz, PRNG_HASH_TIMERS

	mov	#0x7FFF, W0	; then hold counter at halfway through
	mov	W0, TMR5HLD
	mov	W0, TMR4

	bra	PRNG_HASH_TIMERS	; tail call

; note that the per channel background stuff is called only on millisecond
; ticks
per_channel_background:
	rcall	mono_data_from_recent
	and	W1, #0xF, W0

	bra	W0		; jump table
	bra	mono_sq_bk	; Ch 1 mono, CV/gate, velocity, square wave
	bra	duophonic_bk	; Ch 2 duo, CV/gate
	bra	quantize_bk	; Ch 3 quantize to specific MIDI notes
	bra	quantize_bk	; Ch 4 quantize to MIDI notes, all octaves
	bra	arp_updown_bk	; Ch 5 arp up/down, gate/trigger
	bra	arp_inord_bk	; Ch 6 arp in order, gate/trigger
	bra	arp_random_bk	; Ch 7 arp random, gate/trigger
	bra	one_side_bk	; Ch 8 mono left channel, CV/gate
	bra	one_side_bk	; Ch 9 mono right channel, CV/gate
	return			; Ch 10 drum triggers (no background)
	return			; Ch 11 drum gates (no background)
	bra	cv_clock_bk	; Ch 12 mono, CV/gate, clock/reset
	return			; Ch 13 unassigned
	return			; Ch 14 unassigned
	return			; Ch 15 unassigned
	return			; Ch 16 unassigned

; "safe" version of MIDI_BACKGROUND that preserves W0-W7 explicitly,
; other working registers implicitly
.global MIDI_BACKGROUND_SAFE
MIDI_BACKGROUND_SAFE:
	push	W0
	mov	#WREG1, W0
	repeat	#6
	push	[W0++]

	rcall	MIDI_BACKGROUND

	mov	#WREG7, W0
	repeat	#6
	pop	[W0--]
	pop	W0

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Byte stream decoding and message dispatch"

; read one byte of MIDI stream, from W0 low
; may trash W0-W8
.global MIDI_READ_BYTE
MIDI_READ_BYTE:
	clr.b	WREG0H		; make sure high byte is zero

	btst	W0, #7		; check for status byte
	bra	z, read_data_byte

	mov	W0, W1		; put status in W1

	lsr	W0, #4, W0	; look at high nybble
	cp.b	W0, #0xF	; if it's 1111, parse immediately
	bra	eq, MIDI_READ_MESSAGE

	mov	W1, running_status	; save this status byte

	mov	#0x00FF, W3		; all but 1111 need >=1 data byte

reinit_streamed_bytes:
	; figure out whether we'll need a second data byte

	mov	#0x4F00, W4		; mask of nybbles that need 2 bytes
	lsr	W4, W0, W4
	btsc	W4, #0			; "NOW, kid!"
	setm.b	WREG3H

	mov	W3, streamed_bytes	; reinitialize streamed_bytes

	return

read_data_byte:
	cp0	running_status	; discard data with no applicable status
	bra	z, RETURN_INSN

	btst	streamed_bytes, #7	; check for first byte expected
	bra	z, 1f
	mov.b	WREG, streamed_bytes	; store as first byte if we can
	bra	2f

1:
	btsc	streamed_bytes, #15	; check for second byte expected
	mov.b	WREG, streamed_bytes+1	; store as second byte if we can

2:
	btsc	streamed_bytes, #15	; is second byte *still* expected?
	return

	; at this point we have a complete message in streamed_bytes

	mov	running_status, W1	; retrieve status byte
	mov	streamed_bytes, W2	; prepare data bytes

	; figure out how to reinitialize streamed_bytes for next message

	lsr	W1, #4, W0		; look at high nybble of status
	clr	W3			; start with no data needed

	mov	#0xE, W4		; if not 1111 then some data needed
	cpsgt	W0, W4
	setm.b	WREG3L

	rcall	reinit_streamed_bytes

	; bra	MIDI_READ_MESSAGE	; tail call	
	; FALL THROUGH

; read a single pre-parsed MIDI message:  W1 low byte is status (always
; required, no "running status"), W2 is data bytes if applicable.
; may trash W0-W8
.global MIDI_READ_MESSAGE
MIDI_READ_MESSAGE:
	btst	W1, #7		; make sure status byte high bit is set
	bra	z, RETURN_INSN

	clr.b	WREG1H		; clear high byte
	bclr	W2, #7		; clean up high bits
	bclr	W2, #15

	rcall	find_mono_data	; per-message-type subroutines want this

	lsr	W1, #4, W0	; extract bits 4-6 of status byte
	and	W0, #0x7, W0

	bra	W0		; jump table
	clr.b	WREG2H		; 000 note off equiv to 0-velocity note on
	bra	do_note		; 001 note on or off
	bra	save_rstatus	; 010 polyphonic key pressure
	bra	do_cchange	; 011 control change
	bra	save_rstatus	; 100 program change
	bra	save_rstatus	; 101 channel pressure
	bra	do_pbend	; 110 pitch bend
	; FALL THROUGH		; 111 system common and real-time

	mov	#0xF7, W0	; check for "system common"
	cpsgt.b	W1, W0
	clr	running_status	; clear running status, otherwise ignore

	and	W1, #0xF, W0	; mask low bits (to use more convenient cp)

	cp.b	W0, #0x8	; check for "timing clock"
	bra	eq, MIDI_TIMING_CLOCK

	cp.b	W0, #0xA	; check for "start"
	bra	eq, MIDI_TIMING_START

	; other "system" messages are ignored
	return

save_rstatus:
	mov	W1, running_status
	return

do_note:
	mov	W1, running_status	; save status for future use

	and	W1, #0xF, W0	; channel = (low nybble)+1
	mov	recent_channel, W3
	mov	W0, recent_channel

	bra	W0		; jump table
	bra	mono_sq_note	; Ch 1 mono, CV/gate, velocity, square wave
	bra	duophonic_note	; Ch 2 duo, CV/gate
	bra	quantize_note	; Ch 3 quantize to specific MIDI notes
	bra	quantize_note	; Ch 4 quantize to MIDI notes, all octaves
	bra	arp_updown_note	; Ch 5 arp up/down, gate/trigger
	bra	arp_inord_note	; Ch 6 arp in order played, gate/trigger
	bra	arp_inord_note	; Ch 7 arp random, reuses in-order note
	bra	one_side_note	; Ch 8 mono left channel, CV/gate
	bra	one_side_note	; Ch 9 mono right channel, CV/gate
	bra	drum_trig_note	; Ch 10 drum triggers
	bra	drum_gate_note	; Ch 11 drum gates
	bra	cv_clock_note	; Ch 12 mono, CV/gate, clock/reset
	return			; Ch 13 unassigned
	return			; Ch 14 unassigned
	return			; Ch 15 unassigned
	return			; Ch 16 unassigned

do_cchange:
	mov	W1, running_status	; save status for future use
	; FIXME implement control changes
	return

do_pbend:
	mov	W1, running_status	; save status for future use

	sl.b	W2, W2		; unpack the 14-bit number
	lsr	W2, #1, W0

	mov	#8192, W1	; make it signed
	sub	W0, W1, W0

	mov	W0, [W6+2]	; save in data block

	return

; reused in several places
mono_data_from_recent:
	mov	recent_channel, W1

find_mono_data:
	mov	#mono_data, W6
	btsc	W1, #0
	mov	#mono_data+MD_BLOCK_SIZE, W6
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Monophonic with square wave"

; calling convention for this and other "note on" subroutines:
; on entry, W0 is channel number (as MIDI bits, channel 1 = value 0)
; W1 is status byte
; W2 is data bytes (low note, high velocity)
; W3 is former channel
; W6 points at the per-channel data block (data bytes and pitch bend info)
; we're allowed to trash W0-W8

mono_sq_note:
	rcall	use_comparator_int

	mov	#0x0103, W5	; GPIO left, oscillator right
	rcall	pps_remap

	bset	LATB, #7	; both LEDs green
	bset	LATB, #9

	cp0.b	WREG2H		; check for "note off" message
	bra	eq, mono_sq_noteoff

	mov	W2, [W6]	; remember current data bytes

	btg	LATB, #14	; new note always toggles gate

	; raise gate about 1-2ms from now, if we didn't just now
	bset	background_flags, #BF_EAT_1MS
	bset	background_flags, #BF_RAISE_GATE1

	bclr	TRISB, #7	; both LEDs on
	bclr	TRISB, #9

	bclr	W2, #15		; save bits 8-14 of W2 (velocity)
	lsr	W2, #8, W8

	rcall	tune_dac1_oc2	; set DAC1 and OC2 to the note, with bend

	sl	W8, #5, W0	; calculate 12-bit velocity for DAC
	lsr	W8, #2, W8
	add	W0, W8, W0

	bra	WRITE_DAC2	; tail call, send velocity to DAC

mono_sq_bk:
	mov	[W6], W2
	; FALL THROUGH

; Set DAC1 and OC2 to the current note, with pitch bend applied.
; Input note number in W2, W6 pointing at this channel's mono_data variable.
; May trash W0-W7.
tune_dac1_oc2:
	rcall	calc_bent_note

; calculate note number suitable for NOTENUM_TO_DAC[1,2], from MIDI note
; in W2, W6 pointing at channel's mono_data variable.  Returns result in
; W0, trashes W1.
.pushsection *, code
calc_bent_note:
	mov	[W6+2], W0	; pitch bend value (signed)
	mov	[W6+4], W1	; pitch bend range (unsigned)
	mul.su	W0, W1, W0	; scale the pitch bend
	lsr	W0, #13, W0	; divide by 8192
	sl	W1, #3, W1
	ior	W0, W1, W1

	ze	W2, W0		; add note and bend
	swap	W0
	add	W0, W1, W0

	return
.popsection

	rcall	CALC_OSC_TUNING	; figure out the period value

	cp0	W0		; skip updating timer if it'd lock up
	bra	eq, 2f

	mov	W0, OC2RS	; set one period register
	lsr	W0, W1		; set the other
	mov	W1, OC2R

	mov	OC2TMR, W1	; make sure timer is in range
1:
	cp	W1, W0
	bra	ltu, 2f
	sub	W1, W0, W1
	mov	W1, OC2TMR
	bra	1b
2:

	mov	W7, W0		; send note number to DAC
	rcall	NOTENUM_TO_DAC1

	; FALL THROUGH

tempo_from_comparators:
	push	W6	; preserve W6 so we can call inside note/background

	btsc	SOFT_INT_FLAGS, #SI_CM1	; DIN2 is tempo tap / 1 PPQN
	rcall	MIDI_TEMPO_TAP
	bclr	SOFT_INT_FLAGS, #SI_CM1

	btsc	SOFT_INT_FLAGS, #SI_CM3	; DIN1 is 24 PPQN
	rcall	MIDI_TIMING_CLOCK
	bclr	SOFT_INT_FLAGS, #SI_CM3

	pop	W6	; restore saved W6 value

	return

mono_sq_noteoff:
	mov	[W6], W0	; ignore unless it refers to current note
	cp.b	W0, W2
	bra	neq, RETURN_INSN

	mov	W2, [W6]	; remember current data bytes

	bclr	LATB, #14	; gate goes low

	; don't raise the gate later, either
	bclr	background_flags, #BF_RAISE_GATE1

	bset	TRISB, #7	; both LEDs off
	bra	right_led_off

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Duophonic with pitch CV and gate"

duophonic_note:
	bclr	IEC1, #CMIE	; disable comparator interrupts

	mov	#0x0101, W5	; GPIO left and right
	rcall	pps_remap

	bclr	LATB, #7	; both LEDs red
	bclr	LATB, #9

	cp0.b	WREG2H		; check for "note off" message
	bra	eq, duophonic_noteoff

	cp0	duo_side	; if left is most recent, try right first
	bra	z, 1f
	cp0.b	duo_data+1	; if right is free, go there
	bra	z, duophonic_right_noteon
1:

	cp0.b	duo_data+3	; if left is free, go there
	bra	z, duophonic_left_noteon

	cp0.b	duo_data+1	; else if right is free, go there
	bra	z, duophonic_right_noteon

	cp0	duo_side	; else if right is most recent, steal left
	bra	z, duophonic_left_noteon
	; else steal right

duophonic_right_noteon:
	mov	W2, duo_data	; remember current data bytes
	clr	duo_side	; remember we just used the right side

	btg	LATB, #8	; new note always toggles gate

	; raise gate about 1-2ms from now, if we didn't just now
	bset	background_flags, #BF_EAT_1MS
	bset	background_flags, #BF_RAISE_GATE2

	bclr	TRISB, #9	; right LED on

	bra	send_bent_to_dac2	; bend note and send it to DAC2

duophonic_left_noteon:
	mov	W2, duo_data+2	; remember current data bytes
	setm	duo_side	; remember we just used the left side

	btg	LATB, #14	; new note always toggles gate

	; raise gate about 1-2ms from now, if we didn't just now
	bset	background_flags, #BF_EAT_1MS
	bset	background_flags, #BF_RAISE_GATE1

	bclr	TRISB, #7	; left LED on

	bra	send_bent_to_dac1	; bend note and send it to DAC1

duophonic_bk:
	mov	duo_data+2, W2	; bend note and send it to DAC1
	rcall	send_bent_to_dac1

	mov	duo_data, W2	; bend note and send it to DAC2
	bra	send_bent_to_dac2

duophonic_noteoff:
	cp0.b	duo_data+3	; ignore left if it's already off
	bra	z, 1f
	mov	duo_data+2, W0	; check whether we're ending left note
	cp.b	W0, W2
	bra	eq, duophonic_left_noteoff

1:
	cp0.b	duo_data+1	; ignore right if it's already off
	bra	z, RETURN_INSN
	mov	duo_data, W0	; check whether we're ending right not
	cp.b	W0, W2
	bra	neq, RETURN_INSN

	mov	W2, duo_data	; remember current data bytes

	bclr	LATB, #8	; right gate goes low

	; don't raise the gate later, either
	bclr	background_flags, #BF_RAISE_GATE2

	bra	right_led_off	; turn off LED

duophonic_left_noteoff:
	mov	W2, duo_data+2	; remember current data bytes

	bclr	LATB, #14	; left gate goes low

	; don't raise the gate later, either
	bclr	background_flags, #BF_RAISE_GATE1

	bra	left_led_off	; turn off LED

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Quantize to MIDI notes"

quantize_note:
	bclr	IEC1, #CMIE	; disable comparator interrupts

	mov	#0x0101, W5	; GPIO both sides
	rcall	pps_remap

	ze	W2, W0		; divide note num by 12, find remainder
	mov	#12, W3
	repeat	#17
	div.uw	W0, W3

	mov	#quant_notes, W3	; find word containing bit
	sl	W0, W0
	add	W0, W3, W3

	cp0.b	WREG2H		; set Z bit iff note off

	bsw.z	[W3], W1	; write complement of Z bit into array

	return

; do most of the work to quantize a note number (in W0 high with fraction in
; low byte) into a pitch-bent note in W0
quantize_notenum:
	; adjust the rounding according to configured hysteresis amount
	mov	#0x0080+QUANT_HYSTERESIS, W1
	sl	W4, #8, W4
	cpslt	W0, W4
	mov	#0x0080-QUANT_HYSTERESIS, W1

	add	W0, W1, W0	; round off
	lsr	W0, #8, W0

	clr	W1		; find OR of all words in array
	mov	#quant_notes, W4
	repeat	#10
	ior	W1, [W4++], W1

	clr	W7			; loop over notes 0-127
	mov	#quant_notes, W4	; start at first word
	clr	W2			; use note 0 as default
	setm	W5			; infinite distance

1:
	mov	#1, W3		; mod 12 mask starts at bit 0

2:
	btss	recent_channel, #0	; if all-octaves then use ORed bits
	mov	[W4], W1

	and	W3, W1, W6	; check bit for current note
	bra	z, 4f

	sub	W0, W7, W6	; compute distance (absolute value)
	bra	nn, 3f
	neg	W6, W6
3:

	cp	W6, W5		; see if this is a new best
	bra	geu, 4f

	mov	W6, W5		; if it is, save it and its distance
	mov	W7, W2
4:

	inc	W7, W7		; look at next note

	btst	W7, #7		; finished at note 128
	bra	nz, 1f

	sl	W3, W3		; update bit mask

	btst	W3, #12		; continue in this word until bit 12
	bra	z, 2b

	inc2	W4, W4		; go to next word
	bra	1b

1:
	bra	mono_data_from_recent	; W6 for calc_bent_note, tail call

set_quant_led:
	mov	#LATB, W3	; LED goes red iff within a semitone
	cp0	W5
	bsw.z	[W3], W4

	mov	#(quant_previous-7), W0	; W0+W4 points to previous note

	mov	#TRISB, W3	; LED turns off iff infinite distance
	btst	W5, #15
	bsw.z	[W3], W4
	bra	nz, quant_led_off	; skip pulse if LED turns off

	mov	[W0+W4], W3	; skip raising gate if no change
	cp	W3, W2
	bra	eq, 1f

	cp	W4, #7		; check which side we're working on
	bra	neq, 3f

	btg	LATB, #14	; left:  toggle gate, raise it later
	bset	background_flags, #BF_RAISE_GATE1

	bra	2f

3:
	btg	LATB, #8	; right:  toggle gate, raise it later
	bset	background_flags, #BF_RAISE_GATE2

2:
	bset	background_flags, #BF_EAT_1MS	; either side, wait to raise
1:
	mov	W2, [W0+W4]	; save new previous value
	return

quant_led_off:
	cp	W4, #7		; check which side we're working on
	bra	neq, 1f
	
	bclr	LATB, #14	; left:  lower gate, cancel future request
	bclr	background_flags, #BF_RAISE_GATE1

	return

1:
	bclr	LATB, #8	; right:  lower gate, cancel future request
	bclr	background_flags, #BF_RAISE_GATE2

	return

quantize_bk:
	rcall	ADC1_TO_NOTENUM	; get left CV input and quantize it
	mov	quant_previous, W4	; previous value
	rcall	quantize_notenum
	mov	#7, W4		; bit number for left LED
	rcall	set_quant_led
	rcall	send_bent_to_dac1

	rcall	ADC2_TO_NOTENUM	; get right CV input and quantize it
	mov	quant_previous+2, W4	; previous value
	rcall	quantize_notenum
	mov	#9, W4		; bit number for right LED
	rcall	set_quant_led
	bra	send_bent_to_dac2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Arpeggiate up and down"

; shared code for the start of an arpeggiator _note routine
arp_note_top:
	rcall	use_comparator_int

	mov	#0x0102, W5	; GPIO left, pulse right
	rcall	pps_remap

	bset	LATB, #7	; left LED green, right LED red
	bclr	LATB, #9

	mov	#arp_notes, W3		; set up for loop over arp_notes
	mov	arp_note_count, W4
	add	W3, W4, W4

	cp0.b	WREG2H		; check for "note off" message
	return

arp_updown_note:
	rcall	arp_note_top	; set up I/O and check for "note off"
	bra	eq, arp_updown_noteoff

	rcall	arp_search_push	; record the new note
	bra	nz, RETURN_INSN	; if we already have it, break

	mov	#arp_notes, W3	; loop backwards over arp_notes
1:
	cp	W3, W4
	bra	eq, RETURN_INSN
	dec	W4, W5

	mov.b	[W5], W0	; bubble down, or return
	cp.b	W0, [W4]
	bra	ltu, RETURN_INSN

	mov.b	[W5], W0	; swap bytes
	mov.b	[W4], [W5]
	mov.b	W0, [W4--]

	bra	1b

arp_updown_noteoff:
	cp	W3, W4		; search for current note in arp_notes
	bra	eq, RETURN_INSN	; break if not found
	cp.b	W2, [W3++]
	bra	neq, arp_updown_noteoff

	mov.b	[--W4], [--W3]	; move top of stack to where we found note
	dec	arp_note_count

	bra	nz, 1f		; left LED off if stack is empty now
	bset	TRISB, #7

1:
	inc	W3, W5		; loop forwards over arp_notes
	cp	W5, W4
	bra	geu, RETURN_INSN

	mov.b	[W3], W0	; bubble up, or return
	cp.b	W0, [W5]
	bra	ltu, RETURN_INSN

	mov.b	[W5], W0	; swap bytes
	mov.b	[W3], [W5]
	mov.b	W0, [W3++]

	bra	1b

arp_updown_bk:
	mov	#handle(GOTO_W4_INSN), W1
	rcall	TRY
	rcall	arp_bk_top1
	rcall	TRIED

; this part is shared with in-order and random arps
.pushsection *, code
arp_bk_top1:
	rcall	tempo_from_comparators

	mov	#handle(arp_reset), W4	; if no notes, reset arp
	cp0	arp_note_count
	bra	z, THROW

	mov	TEMPO_CLOCK, W0	; reduce TEMPO_CLOCK mod 24
1:
	cp	W0, #24
	bra	ltu, 1f
	sub	W0, #24, W0
	bra	1b
1:

	mov	#handle(arp_beat_end), W4	; if end of beat, go silent
	cp	W0, #21
	bra	geu, THROW

	mov	#handle(RETURN_INSN), W4	; if no beat, wait for one
	btst	SOFT_INT_FLAGS, #SI_BEAT
	bra	z, THROW
	bclr	SOFT_INT_FLAGS, #SI_BEAT	; and then clear it

	bset	LATB, #14	; gate up
	bclr	TRISB, #9	; right LED on

	mov	#0x0404, W1	; send a trigger pulse
	mov	W1, OC2CON1

	return
.popsection

	; note in up/down version we increment the left side AFTER using it,
	; but decrement the right side BEFORE using it, so that at the
	; outset we will start at opposite ends

	rcall	arp_bk_top2

; this part is shared with in-order, but not random, arps
.pushsection *, code
arp_bk_top2:
	mov.b	arp_index+1, WREG	; get left-side arp index

	rcall	reduce_and_find_note
.pushsection *, code
reduce_and_find_note:
	clr.b	WREG0H		; make sure high byte is zero

	cp	arp_note_count		; reduce it modulo arp_note_count
	bra	gt, 1f
	subr	arp_note_count, WREG
	bra	reduce_and_find_note

1:
	mov	#arp_notes, W3	; find the note we'll play
	mov.b	[W0+W3], W2

	return
.popsection

	inc	W0, W0		; increment index, and save it
	mov.b	WREG, arp_index+1

	bra	send_bent_to_dac1
.popsection

	dec.b	arp_index, WREG	; get right-side arp index, decrement it
	add	arp_note_count, WREG

	rcall	reduce_and_find_note

	mov.b	WREG, arp_index	; save the new note

	bra	send_bent_to_dac2

arp_reset:
	clr	arp_index	; reset arpeggiation to start
	bclr	SOFT_INT_FLAGS, #SI_BEAT	; wait for a beat

arp_beat_end:
	bclr	LATB, #14	; gate down

right_led_off:
	bset	TRISB, #9	; right LED off
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Arpeggiate in order notes were entered"

arp_inord_note:
	rcall	arp_note_top	; set up I/O and check for "note off"
	bra	eq, arp_inord_noteoff

; shared code:  search for current note in arp_notes, and if not found,
; turn on the left LED and push new note on arp_notes.  Returns NZ iff found.
arp_search_push:
	cp	W3, W4		; search for current note in arp_notes
	bra	eq, 1f
	cp.b	W2, [W3++]
	bra	eq, NZ_RETURN	; break if found
	bra	arp_search_push
1:

	bclr	TRISB, #7	; left LED on

	mov.b	W2, [W4]	; push new note on arp_notes
	inc	arp_note_count

	bra	Z_RETURN

arp_inord_noteoff:
	cp	W3, W4		; search for current note in arp_notes
	bra	eq, RETURN_INSN	; break if not found
	cp.b	W2, [W3++]
	bra	neq, arp_inord_noteoff

1:
	cp	W3, W4		; shift subsequent notes down
	bra	eq, 1f
	mov.b	[W3++], W0
	mov.b	W0, [W3-2]
	bra	1b
1:

	dec	arp_note_count	; shrink stack

	bra	nz, 1f		; left LED off if stack is empty now
left_led_off:
	bset	TRISB, #7
1:
	return

arp_inord_bk:
	mov	#handle(GOTO_W4_INSN), W1	; reuse code from up/down
	rcall	TRY
	rcall	arp_bk_top1
	rcall	TRIED
	rcall	arp_bk_top2

	mov.b	arp_index+1, WREG	; right is actually future of left

reduce_bend_dac2:
	rcall	reduce_and_find_note

	bra	send_bent_to_dac2	; reuse code from "up/down" arpeggiator

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Arpeggiate randomly"

; we reuse the note on/off subroutine from in-order arp for this one

arp_random_bk:
	mov	#handle(GOTO_W4_INSN), W1	; reuse code from up/down
	rcall	TRY
	rcall	arp_bk_top1
	rcall	TRIED

	mov	arp_note_count, W3	; get number of choices
	mov	arp_index, W4		; get previous notes
	clr	arp_index		; default to zero for new notes

	cp	W3, #1		; if we only have one held note use it
	bra	eq, 1f

	dec	W3, W1		; make a pseudorandom choice for right
	rcall	PRNG_READ_INT
	mov.b	WREG, arp_index	; use unconditionally

4:
	rcall	PRNG_READ_INT	; make a pseudorandom choice for left

	cp	W3, #2		; if we can afford it, avoid new right
	bra	ltu, 5f
	cp.b	arp_index
	bra	eq, 4b

	cp	W3, #3		; if we can afford it, avoid old left
	bra	ltu, 5f
	cp.b	WREG4H
	bra	eq, 4b

5:
	mov.b	WREG, arp_index+1	; save choice for left
1:

	rcall	reduce_and_find_note	; use this note on the left
	rcall	send_bent_to_dac1

	mov.b	arp_index, WREG	; get chosen note on right, use it
	bra	reduce_bend_dac2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Monophonic CV/gate on one side"

one_side_note:
	bclr	IEC1, #CMIE	; disable comparator interrupts

	mov	#0x0101, W5	; GPIO both sides
	rcall	pps_remap

	bset	LATB, #7	; both LEDs green
	bset	LATB, #9

	cp0.b	WREG2H		; check for "note off" message
	bra	eq, one_side_noteoff

	mov	W2, [W6]	; remember current data bytes

	; delay for note change
	bset	background_flags, #BF_EAT_1MS

	btst	W1, #0		; which side are you on, boys?
	bra	z, right_side_noteon

	btg	LATB, #14	; new note always toggles gate

	; be sure gate goes up later if it isn't up now
	bset	background_flags, #BF_RAISE_GATE1

	bclr	TRISB, #7	; left LED on

send_bent_to_dac1:
	rcall	calc_bent_note
	bra	NOTENUM_TO_DAC1	; tail call

right_side_noteon:
	btg	LATB, #8	; new note always toggles gate

	; be sure gate goes up later if it isn't up now
	bset	background_flags, #BF_RAISE_GATE2

	bclr	TRISB, #9	; left LED on

send_bent_to_dac2:
	rcall	calc_bent_note
	bra	NOTENUM_TO_DAC2	; tail call

one_side_bk:
	mov	#mono_data+MD_BLOCK_SIZE, W6	; handle left channel
	mov	[W6], W2
	rcall	send_bent_to_dac1

	mov	#mono_data, W6		; handle right channel
	mov	[W6], W2
	bra	send_bent_to_dac2	; tail call

one_side_noteoff:
	mov	[W6], W0	; ignore unless it refers to current note
	cp.b	W0, W2
	bra	neq, RETURN_INSN

	mov	W2, [W6]	; remember current data bytes

	btst	W1, #0		; which side are you on, boys?
	bra	z, right_side_noteoff

	bclr	LATB, #14	; gate goes low

	; don't raise the gate later, either
	bclr	background_flags, #BF_RAISE_GATE1

	bra	left_led_off

right_side_noteoff:
	bclr	LATB, #8	; gate goes low

	; don't raise the gate later, either
	bclr	background_flags, #BF_RAISE_GATE2

	bra	right_led_off

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Drum triggers"

drum_trig_note:
	mov	#0x0202, W5	; pulse output both sides

	rcall	drum_note_start
.pushsection *, code
drum_note_start:
	rcall	pps_remap

	bclr	IEC1, #CMIE	; disable comparator interrupts

	mov	W2, W0		; do note mapping
	lsr	W0, #2, W0
	add	W2, W0, W0
	and	W0, #3, W0

	mov	#drum_notes, W1	; point W1 at drum state

	cp0.b	WREG2H		; check for "note off" message
	bsw.z	[W1], W0	; update status bit

	return
.popsection

	bra	z, drum_leds	; note off just sets the LEDs

	mul.uu	W0, #10, W2	; index into array of OC modules
	mov	#OC1CON1, W1
	add	W1, W2, W2

	mov	#0x0404, W1	; start the OC counting
	mov	W1, [W2]

	cp	W0, #2		; raise gate on DAC1 if appropriate
	bra	neq, 1f
	mov	#0x0FFF, W0
	rcall	WRITE_DAC1
	bra	drum_leds

1:
	cp	W0, #3		; raise gate on DAC2 if appropriate
	bra	neq, drum_leds
	mov	#0x0FFF, W0
	rcall	WRITE_DAC2

drum_leds:
	mov	drum_notes, W2	; get drum status

	mov	LATB, W1	; get LATB
	ior	#0x0280, W1	; default bits 7 and 9 to set

	btsc	W2, #2		; left LED red if note 2
	bclr	W1, #7

	btsc	W2, #3		; right LED red if note 3
	bclr	W1, #9

	mov	W1, LATB	; save LATB

	mov	TRISB, W1	; get TRISB
	ior	#0x0280, W1	; default bits 7 and 9 to set

	and	W2, #5, W0	; check bits 0 and 2 of note status
	bra	z, 1f
	bclr	W1, #7		; left LED on if either is set
1:

	and	W2, #10, W0	; check bits 1 and 3 of note status
	bra	z, 1f
	bclr	W1, #9		; right LED on if either is set
1:

	mov	W1, TRISB	; save TRISB

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Drum gates"

drum_gate_note:
	mov	#0x0101, W5	; GPIO both sides

	rcall	drum_note_start	; shared code with drum trigger channel

	bra	z, drum_gate_noteoff	; check for "note off" message

	sl	W0, W1		; scale index for table
	mov	#0x0FFF, W0	; value for DACs

	cp	W1, #4		; check for note in shared part of table
	bra	geu, 1f

	add	W1, #8, W1	; otherwise, shift into later entries
	bra	1f

drum_gate_noteoff:
	sl	W0, W1		; scale index for table
	clr	W0		; value for DACs

1:
	bra	W1		; jump into table according to note
	bclr	LATB, #14	; note 0 off - clear RB14, DOUT1
	bra	drum_leds
	bclr	LATB, #8	; note 1 off - clear RB8, DOUT2
	bra	drum_leds
	rcall	WRITE_DAC1	; note 2 - DAC1 goes high
	bra	drum_leds
	rcall	WRITE_DAC2	; note 3 - DAC2 goes high
	bra	drum_leds
	bset	LATB, #14	; note 0 on - set RB14, DOUT1
	bra	drum_leds
	bset	LATB, #8	; note 1 on - set RB8, DOUT2
	bra	drum_leds

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Monophonic with clock/reset out"

use_comparator_int:
	cp	W0, W3		; clear comparator intrs if new channel
	bra	eq, 1f
	bclr	IFS1, #CMIF
	bclr	SOFT_INT_FLAGS, #SI_CM3
	bclr	SOFT_INT_FLAGS, #SI_CM1
1:
	bset	IEC1, #CMIE	; and enable future ones
	return

cv_clock_note:
	rcall	use_comparator_int

	mov	#0x0202, W5	; map both digital outs to pulse
	rcall	pps_remap

	bset	LATB, #7	; left LED green

	cp0.b	WREG2H		; check for "note off" message
	bra	eq, cv_clock_noteoff

	mov	[W6], W1	; get old data byte, save new one
	mov	W2, [W6]

	clr	W0		; gate high iff silent before, else low
	cp0.b	WREG1H
	bra	z, 1f
	mov	#0x0FFF, W0
1:
	rcall	WRITE_DAC2

	; raise gate about 1-2ms from now, if we didn't just now
	bset	background_flags, #BF_EAT_1MS
	bset	background_flags, #BF_RAISE_CV2

	bclr	TRISB, #7	; both LEDs on
	bclr	TRISB, #9

	rcall	right_led_beat_colour	; set colour according to beat

	bra	send_bent_to_dac1	; tail call

cv_clock_noteoff:
	mov	[W6], W0	; ignore unless it refers to current note
	cp.b	W0, W2
	bra	neq, RETURN_INSN

	mov	W2, [W6]	; remember current data bytes

	clr	W0		; gate goes low
	rcall	WRITE_DAC2

	; don't raise the gate later, either
	bclr	background_flags, #BF_RAISE_CV2

	bset	TRISB, #7	; left LED off

	; FALL THROUGH

right_led_beat_state:
	btss	BEAT_FLASH, #0	; right LED off unless beat flash
	bset	TRISB, #9
	btsc	BEAT_FLASH, #0
	bclr	TRISB, #9

	; FALL THROUGH

right_led_beat_colour:
	btss	BEAT_FLASH, #0	; green if not beat flash
	bset	LATB, #9
	btsc	BEAT_FLASH, #0	; red if beat flash
	bclr	LATB, #9

	return

cv_clock_bk:
	mov	[W6], W2	; update DAC for pitch bend

	cp0.b	WREG2H		; set right LED per beat and gate
	bra	z, 1f
	rcall	right_led_beat_colour
	bra	2f
1:
	rcall	right_led_beat_state
2:

	rcall	send_bent_to_dac1

	rcall	tempo_from_comparators

	btst	SOFT_INT_FLAGS, #SI_BEAT	; pulse on new beat
	bra	z, 1f
	bclr	SOFT_INT_FLAGS, #SI_BEAT

	mov	#0x0404, W0	; initiate 960us reset pulse
	mov	W0, OC2CON1

	; wait another millisecond before trying to pulse OC1
	bset	background_flags, #BF_EAT_1MS
	return

1:
	mov	TEMPO_CLOCK, W0
	cp	pulsed_tick
	bra	eq, 2f
	mov	W0, pulsed_tick

	mov	#0x0404, W0	; initiate 960us clock pulse
	mov	W0, OC1CON1

2:
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "PPS mapping"

; takes the desired value of the pps_status variable in W5
; trashes W0, W3-W5, preserves W1 and W2
pps_remap:
	mov	pps_status, W3	; do nothing if already mapped as desired
	cp	W5, W3
	bra	eq, RETURN_INSN

	rcall	UNLOCK_PPS	; else we must unlock

	mov.b	pps_status+1, WREG	; get left channel mapping

	mov	#OC1CON1, W4	; configure OC1 when we call config_oc_*

	lsr	W5, #8, W3	; compare with desired value
	cpseq.b	W0, W3		; if as desired, skip to do-nothing entry
	bra	W3		; jump table
	bra	1f		; 00 don't change left mapping
	bra	pps_left_gpio	; 01 left GPIO
	bra	pps_left_pulse	; 10 left pulse
	; FALL THROUGH		; 11 left oscillator

	rcall	config_oc_osc	; configure OC1 as oscillator
	bclr	IEC0, #OC1IE	; disable OC1 interrupts
	bra	2f

pps_left_pulse:
	rcall	config_oc_pulse	; configure OC1 for pulse
	bclr	IFS0, #OC1IF	; request future OC1 interrupts
	bset	IEC0, #OC1IE

	; FALL THROUGH

2:
	mov	#0x0012, W0	; PPS map RP14 to OC1
	mov	W0, RPOR7
	bra	1f

pps_left_gpio:
	clr	RPOR7		; PPS unmap RP14 (becomes GPIO)
	; FALL THROUGH

1:
	mov.b	pps_status, WREG	; get right channel mapping

	mov	#OC2CON1, W4	; configure OC2 when we call config_oc_*

	and	W5, #3, W3	; compare with desired value
	cpseq.b	W0, W3		; if as desired, skip to do-nothing entry
	bra	W3		; jump table
	bra	1f		; 00 don't change right mapping
	bra	pps_right_gpio	; 01 right GPIO
	bra	pps_right_pulse	; 10 right pulse
	; FALL THROUGH		; 11 right oscillator

	rcall	config_oc_osc	; configure OC2 as oscillator
	bclr	IEC0, #OC2IE	; disable OC2 interrupts
	bra	2f

pps_right_pulse:
	rcall	config_oc_pulse	; configure OC2 for pulse
	bclr	IFS0, #OC2IF	; request future OC2 interrupts
	bset	IEC0, #OC2IE

	; FALL THROUGH

2:
	mov	#0x0013, W0	; PPS map RP8 to OC2
	mov	W0, RPOR4
	bra	1f

pps_right_gpio:
	clr	RPOR4		; PPS unmap RP8 (becomes GPIO)
	; FALL THROUGH

1:
	mov	W5, pps_status	; save new status

	bra	LOCK_PPS	; lock back up again, tail call

; configure OC module to send a 960us pulse.
; W4 should point at OCxCON1 when calling this
config_oc_pulse:
	mov	#0x0400, W0	; use T3 prescaler, disable module for now
	mov	W0, [W4++]	; OCxCON1
	mov	#0x001F, W0	; sync this OC module from itself
	mov	W0, [W4++]	; OCxCON2
	mov	#1921, W0	; pulse width 960us (1920 counts at 2MHz)
	mov	W0, [W4++]	; OCxRS
	mov	#1, W0		; start pulse on next count after request
	mov	W0, [W4++]	; OCxR
	return

; configure OC module as audio oscillator.
; W4 should point at OCxCON1 when calling this
config_oc_osc:
	mov	#0x0406, W0	; use T3 prescaler, edge-aligned PWM
	mov	W0, [W4++]	; OCxCON1
	mov	#0x001F, W0	; sync this OC module from itself
	mov	W0, [W4++]	; OCxCON2
	clr	[W4++]		; OCxRS
	clr	[W4++]		; OCxR
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Tempo timing"

.global MIDI_TIMING_CLOCK, MIDI_TIMING_START, MIDI_TEMPO_TAP

set_beat_flag:
	bset	SOFT_INT_FLAGS, #SI_BEAT
	mov	#0x5001, W0	; 80ms flash duration
	mov	W0, BEAT_FLASH
	return

; accept a MIDI 24 PPQN clock pulse.  Trashes W0 and W1.
MIDI_TIMING_CLOCK:
	inc	TEMPO_CLOCK, WREG	; increment clock

	mov	#47, W1		; push clock to at least 48
	cpsgt	W0, W1
	add	W0, #24, W0
	cpsgt	W0, W1
	add	W0, #24, W0

	mov	#72, W1		; pull clock to no more than 71
	cpslt	W0, W1
	sub	W0, #24, W0

	mov	W0, TEMPO_CLOCK	; save result

	mov	#48, W1		; beat if we've hit 48 exactly
	cpsne	W0, W1
	rcall	set_beat_flag

	bra	start_of_tick	; reuse start-of-tick code below

; MIDI sync reset.  Trashes W0.
MIDI_TIMING_START:
	mov	#47, W0		; set clock to just before beat, disable tap
	mov	W0, TEMPO_CLOCK

start_of_tick:
	clr	TMR5HLD		; start of tick
	clr	TMR4

	setm	PR5		; maximum period (effectively stopped)
	setm	PR4

	return

; process a "tap tempo" event.  Trashes W0-W7.
MIDI_TEMPO_TAP:
	; get timer value and reset timer
	mov	#1, W0
	disi	#8
	bclr	T4CON, #TON
	mov	TMR4, W2
	mov	TMR5HLD, W3
	mov	TEMPO_CLOCK, W1
	clr	TEMPO_CLOCK
	clr	TMR5HLD
	mov	W0, TMR4	; reset to 1 because we turn off for 8 insns
	bset	T4CON, #TON

	rcall	set_beat_flag

	; TEMPO_CLK values 32 and above:  start over
	cp	W1, #31
	bra	leu, 1f
	setm	PR5		; set the period back to maximum
	setm	PR4
	return
1:

	; compute time since last complete reset into W5:W4
	mov	PR4, W4		; get timer period
	mov	PR5, W5
	inc	W4, W4
	addc	W5, #0, W5

	mul.uu	W1, W5, W6	; time from ticks already past, high part
	mul.uu	W1, W4, W4	; low part
	add	W6, W5, W5	; accumulate

	add	W2, W4, W4	; add in time from current tick
	addc	W3, W5, W5

	mov	W1, W6		; save TEMPO_CLOCK

	mov	#24, W3		; divide time in W5:W4 by 24 for new period
	repeat	#17		; high word
	div.uw	W5, W3
	exch	W0, W4		; save result high, get time low
	repeat	#17
	div.ud	W0, W3		; low word and remainder

	; at this point the period we just measured is in W4:W0 (P)

	; TEMPO_CLOCK values 0..21, 26..31:  set period to time we measured
	cp	W6, #21
	bra	leu, 1f
	cp	W6, #26
	bra	geu, 1f

	; TEMPO_CLOCK values 22..25:  moving average with earlier period
	mov	PR5, W3		; get old period (Q) in W3:W2
	mov	PR4, W2

	; using CPU multiply would end up costing 6 insns anyway
	add	W2, W0, W0	; compute Q+P
	addc	W3, W4, W4
	add	W2, W0, W0	; compute 2*Q+P
	addc	W3, W4, W4
	add	W2, W0, W0	; compute 3*Q+P
	addc	W3, W4, W4

	lsr	W4, W4		; divide by 2
	rrc	W0, W0
	lsr	W4, W4		; divide by 2 again
	rrc	W0, W0

1:
	mov	W4, PR5		; use the new period
	mov	W0, PR4

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Interrupt service routines"

.section .isr, code

; T5 ISR handles the 32-bit T4/5.  Bump TEMPO_CLOCK, with special wrapping
.global __T5Interrupt
__T5Interrupt:
	push	W0

	bclr	IFS1, #T5IF	; acknowledge interrupt

	inc	TEMPO_CLOCK	; bump clock counter

	mov	#72, W0		; check it hasn't overflowed
	cp	TEMPO_CLOCK
	bra	ltu, 1f

	mov	#24, W0		; if it has, jump back a beat
	sub	TEMPO_CLOCK

1:
	mov	#48, W0		; this is a beat if we hit 48..
	cp	TEMPO_CLOCK
	bra	eq, 1f

	mov	#24, W0		; or if we hit 24
	cp	TEMPO_CLOCK
	bra	neq, RETFIE_W0

1:	
	rcall	set_beat_flag
	bra	RETFIE_W0

; Silicon erratum for output compare:  we need to wait two prescaler cycles,
; therefore 16 instruction cycles at 1:8, after interrupt flag before
; clearing the mode bits.  Also, not clearly explained in the reference
; manual, we need to clear the mode bits before re-setting them to start a
; new pulse.  We handle this by implementing ISRs for each output compare
; that is used to generate pulses.  The ISRs wait through the 16 cycles and
; then clear the mode bits.  Foreground won't regain control until shortly
; after that, at which time it should be safe to request another pulse.

; rcall this to delay 16 cycles:
;   2 for rcall
;   1 for push
;   1 for repeat
;   8 for 8 repetitions of nop
;   1 for pop
;   3 for return
oc_safety_delay:
	push	RCOUNT
	repeat	#7
	nop
	pop	RCOUNT
	return

; OC1 and OC2 ISRs called to prepare these output compares for new pulses

.global __OC1Interrupt
__OC1Interrupt:
	push	W0	; save W0

	rcall	oc_safety_delay	; work around silicon erratum

	bclr	IFS0, #OC1IF	; acknowledge interrupt

	mov	#0x0400, W0	; prepare OC1 for another pulse
	mov	W0, OC1CON1

delayed_retfie_w0:
	rcall	oc_safety_delay	; work around silicon erratum
	bra	RETFIE_W0

.global __OC2Interrupt
__OC2Interrupt:
	push	W0	; save W0

	rcall	oc_safety_delay	; work around silicon erratum

	bclr	IFS0, #OC2IF	; acknowledge interrupt

	mov	#0x0400, W0	; prepare OC2 for another pulse
	mov	W0, OC2CON1

	bra	delayed_retfie_w0

; OC3 and OC4 ISRs called to end trigger pulses sent through the DACS

.global __OC3Interrupt
__OC3Interrupt:
	push	W0		; save W0

	rcall	oc_safety_delay	; work around silicon erratum

	bclr	IFS1, #OC3IF	; acknowledge interrupt

	mov	#0x0400, W0	; prepare OC3 for another pulse
	mov	W0, OC3CON1

	clr	W0		; send a zero to the DAC
	rcall	WRITE_DAC1

	bra	RETFIE_W0	; no delay, write to DAC is >16 cycles

.global __OC4Interrupt
__OC4Interrupt:
	push	W0		; save W0

	rcall	oc_safety_delay	; work around silicon erratum

	bclr	IFS1, #OC4IF	; acknowledge interrupt

	mov	#0x0400, W0	; prepare OC4 for another pulse
	mov	W0, OC4CON1

	clr	W0		; send a zero to the DAC
	rcall	WRITE_DAC2

	bra	RETFIE_W0	; no delay, write to DAC is >16 cycles

.end
