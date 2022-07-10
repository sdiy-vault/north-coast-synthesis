.psize 44,144
.title "USB class-compliant MIDI device driver"
.sbttl "$Id: usbmidi.s 9802 2022-01-28 23:27:05Z mskala $"
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

.pushsection til_usbmidi, code
	mov	#handle(usb_midi_driver), W4
	mov	#0x0301, W5	; class 1 "audio", sub 3 "MIDI streaming"
	rcall	TPL_MATCH_INTERFACE_CLASS
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Data structures"

; Memory layout to be compatible with FIND_IN_OUT_ENDPOINTS
in_common	in_ep_ptr, 2
in_common	out_ep_ptr, 2

; We will allow for up to eight endpoints, though we only use the first
; input endpoint we find, just in case some MIDI device has a weird
; descriptor with bulk transfer endpoints.  Endpoints are in the common area
; so the space doesn't really cost anything.
in_common	ep_1, ENDPOINT_SIZE
in_common	ep_2, ENDPOINT_SIZE
in_common	ep_3, ENDPOINT_SIZE
in_common	ep_4, ENDPOINT_SIZE
in_common	ep_5, ENDPOINT_SIZE
in_common	ep_6, ENDPOINT_SIZE
in_common	ep_7, ENDPOINT_SIZE
in_common	ep_8, ENDPOINT_SIZE

; IRP for our bulk transfers
in_common	bulk_irp_flags, 2
in_common	bulk_irp_size, 2
in_common	bulk_irp_buffer, 2
in_common	bulk_irp_fill, 2

; buffer for data from device, size rounded for alignment
in_common	buffer, (64+BUFFER_SAFETY_MARGIN+1)&0xFFFE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Driver init and bulk transfer"

.section .text

usb_midi_driver:
	; configure the device
	mov	#ep_1, W8
	mov	#8, W9
	rcall	USB_CONFIGURE_DEVICE
	rcall	FIND_IN_OUT_ENDPOINTS

	cp0	in_ep_ptr	; we must have an input
	bra	z, COMPLAIN_ABOUT_DEVICE

	rcall	MIDI_INIT

prepare_bulk_request:
	mov	in_ep_ptr, W13	; W13 points at endpoint flag field
	bset	[++W13], #EPF_INFINITE_NAK	; Romans 8:25

	bclr	[W13], #EPF_STALLED	; clear any error that may exist
	clr	W0
	mov	W0, [W13+10]

	; initialize each field of the IRP
	mov	#(IRPFM_UOWN|IRPFM_BULK), W0
	mov	W0, bulk_irp_flags
	mov	[W13+6], W0
	mov	W0, bulk_irp_size
	mov	#buffer, W0
	mov	W0, bulk_irp_buffer
	clr	bulk_irp_fill

	mov	#bulk_irp_flags, W0	; point endpoint at IRP
	mov	W0, [W13+4]

	mov	#2, W0		; baseline is 2000 tokens per second
	mov	W0, TOKEN_ALLOWANCE

wait_for_data:
	rcall	MIDI_BACKGROUND

	inc	TOKEN_STORE	; also allow an extra token per loop
	rcall	USB_POKE
	pwrsav	#1

	rcall	USB_TEST_ATTACHED	; make sure we still have a device
	bra	z, RETURN_INSN

	btst	bulk_irp_flags, #IRPF_UOWN	; check transaction complete
	bra	nz, wait_for_data

	btst	bulk_irp_flags, #IRPF_ERROR	; check for error
	bra	z, got_data

	; FIXME
	; we have an error.  check how bad it is and maybe THROW.
	; otherwise, we'll just clear it and keep retrying.

	bra	prepare_bulk_request

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "USB-MIDI packet decoding"

got_data:
	mov	bulk_irp_fill, W7	; make sure we really have got
	cp	W7, #4
	bra	ltu, prepare_bulk_request

	; The MPK Mini, at least - and if it does this then others probably
	; do, too - sends 64 bytes of what looks like garbage at initial
	; connection.  Maybe it's associated with some higher level of the
	; protocol that we don't understand.  It comes in in a valid USB
	; transaction, no error, so it seems to be happening on purpose. 
	; Anyway, we scan the USB packet for 32-bit MIDI packets with
	; nonzero padding bytes, which are forbidden by the USB MIDI 1.0
	; spec, and reject the whole USB packet if we find any.

	mov	#buffer, W2	; loop over USB packet
	mov	#0xB064, W5	; mask of CINs known to have >=1 pad byte
	mov	#0x8020, W6	; mask of CINs known to have two pad bytes
1:
	mov	[W2++], W3	; get MIDI packet into W4:W3
	mov	[W2++], W4

	btst.z	W5, W3		; check for code with >=1 pad byte
	bra	z, 2f
	cp0.b	WREG4H		; if so, last byte needs to be zero
	bra	nz, prepare_bulk_request
2:

	btst.z	W6, W3		; check for code with two pad bytes
	bra	z, 2f
	cp0.b	WREG4L		; if so, second-last byte needs to be zero
	bra	nz, prepare_bulk_request
2:

	sub	W7, #4, W7	; loop until end of packet
	bra	gtu, 1b

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; now actually go through the USB packet, sending it to backend

	mov	#buffer, W13	; using W13 to avoid conflict with backend
1:
	mov	[W13++], W1	; packet into W2:W1 per backend arguments
	mov	[W13++], W2

	mov	#0x4B2C, W0	; mask of CINs we pass as parsed events
	btst.z	W0, W1
	bra	z, 2f

	lsr	W1, #8, W1	; move status byte to low byte
	rcall	MIDI_READ_MESSAGE	; send it to backend
	bra	3f
2:

	mov	#0x8000, W0	; mask of the one CIN we pass as single byte
	btst.z	W0, W1
	bra	z, 3f

	lsr	W1, #8, W0	; move status byte to low byte
	rcall	MIDI_READ_BYTE	; send it to backend

3:
	mov	#buffer, W0	; check for running over end of buffer
	add	bulk_irp_fill, WREG
	cp	W13, W0
	bra	ltu, 1b

	bra	prepare_bulk_request

.end
