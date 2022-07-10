.psize 44,144
.title "USB driver"
.sbttl "$Id: usb.s 10191 2022-07-04 02:03:52Z mskala $"
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

; BDT gets its own section because it needs to be aligned
; we need to fix it at a calculated address because we need to load the page
; address into the USB hardware for DMA, finding the page address of a
; symbol that has been relocated doesn't seem to be within the scope of
; calculations the linker can perform, and we don't want to make the CPU do
; it at run time.
.equ bdt_page, 0x10
.section *, bss, address(bdt_page<<8)

start_clear:

bdt:
bdt_rx:
bdt_rx_stat:	.skip 2
bdt_rx_addr:	.skip 2
bdt_tx:
bdt_tx_stat:	.skip 2
bdt_tx_addr:	.skip 2

; merge our data into the BDT section so we can fix the offset difference
; between BDT and the associated _irp variables, and clear it all at once

; layout is important here.  These four variables echo the layout of the
; BDT immediately before them.

rx_irp:		.skip 2
rx_ep:		.skip 2
tx_irp:		.skip 2
tx_ep:		.skip 2

.equ	soft_bdt_offset, rx_irp-bdt_rx

endpoint_ll:		.skip 2
current_endpoint:	.skip 2

loop_wait_ms:	.skip 2

.global USB_FLAGS, TOKEN_STORE, TOKEN_ALLOWANCE

USB_FLAGS:		.skip 2
TOKEN_STORE:		.skip 2
TOKEN_ALLOWANCE:	.skip 2

.if UF_BUSY_WATCHDOG_TIME>0
uf_busy_watchdog:	.skip 2
.endif

; these are saved outside the common area so drivers can still make calls
; that need them, after trashing the common area
saved_iface_index:	.skip 1
saved_conf_index:	.skip 1

ep0:
ep0_next:	.skip 2
ep0_flags:	.skip 2
ep0_number:	.skip 1
ep0_address:	.skip 1
ep0_irp:	.skip 2
ep0_max_packet:	.skip 2
ep0_nak_count:	.skip 2
ep0_error:	.skip 2

end_clear:

; Data structures:
;
; Endpoint (14 bytes):
;  0-1    next (linked-list pointer to next endpoint)
;  2-3    flags (high byte is bmAttributes field of descriptor)
;  4      endpoint number
;  5      address
;  6-7    pointer to current IRP
;  8-9    max packet size
;  10-11  NAK count
;  12-13  error, or interval
;
; general IRP (8 bytes):
;  0-1    flags
;  2-3    buffer size
;  4-5    buffer address
;  6-7    buffer fill point
;
; control IRP (8 bytes plus buffer):
;  0-1    flags
;  2-3    buffer size
;  4-5    buffer address, always points at offset 10 in this IRP
;  6-7    buffer fill point (0 until setup is sent, then starts at 8)
;  8-15   first 8 bytes of buffer, containing setup message
;

; Saved copies of the device and interface descriptors, for use during
; configuration, and the associated loop counters

in_common	saved_dev_desc, 18
in_common	saved_conf_desc, 10
in_common	current_conf, 2
in_common	current_iface, 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "USB initialization/finalization"

.section .text

.global USB_INIT
USB_INIT:
	bclr	IEC5, #USB1IE	; turn off USB interrupts for now

	; software init

	mov	#start_clear, W0	; clear variables that need it
	repeat	#((end_clear-start_clear-2)/2)
	clr	[W0++]
	; that also clears the BDT

	; hardware init

	mov	#bdt_page, W0	; tell the hardware where we put the BDT
	mov	W0, U1BDTP1

	mov	#0x8, W0	; host mode
	mov	W0, U1CON

	mov	#0x30, W0	; host mode, no OTG, no fancy power
	mov	W0, U1OTGCON

	clr	U1CNFG1		; no ping-pong
	clr	U1CNFG2		; no external transciever
	clr	U1PWMCON	; no power PWM
	clr	U1ADDR		; address is zero, not low speed for now

	; Microchip's driver uses 0x4A, as recommended by the data sheet,
	; but user "Tsuneo" on the Microchip Web forum makes a convincing
	; argument that that is not enough and the correct value should
	; be 0x5A
	mov	#0x5A, W0	; SOF threshold for 64-byte packets
	mov	W0, U1SOF

	mov	#1, W0		; power up the USB module
	mov	W0, U1PWRC

	; interrupt init

	setm	U1OTGIR		; clear any pending interrupts
	setm	U1EIR
	setm	U1IR

	bclr	U1IE, #SOFIE	; disable SOF interrupt
	bset	U1OTGIE, #T1MSECIE	; enable 1ms interrupt
	bset	U1IE, #ATTACHIE		; enable device attach interrupt

	bset	IEC5, #USB1IE	; enable USB multiplexed interrupt

	return

.global USB_DONE
USB_DONE:
	bclr	IEC5, #USB1IE	; turn off USB multiplexed interrupt

	clr	U1OTGCON
	clr	U1CON
	clr	U1PWRC

	clr	USB_FLAGS

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "USB session handler"

.section _tpl_init, code

; handle the entire session of an attached device:  start communicating with
; it, enumerate it, go run the appropriate driver, etc.  THROWs if something
; goes wrong; returns if session completes nicely.
.global USB_HANDLE_SESSION
USB_HANDLE_SESSION:
	; stack reservation is one IRP, one CTRL SETUP packet, plus the
	; biggest config descriptor return we'll accept, plus safety margin,
	; rounded up to even number
	.equ split_line, IRP_SIZE+SETUP_SIZE+MAX_DESCRIPTOR_SIZE
	lnk #((split_line+BUFFER_SAFETY_MARGIN+1)&0x3FFE)

	mov	#100, W0	; wait 100ms for power to stabilize
	rcall	USB_WAIT

	; after a lot of experiment, it appears that the safest way to test
	; speed is to test it only once, before the reset.
	rcall	USB_TEST_SPEED
	bra	nz, 1f		; left LED was green, goes red on low speed
	bclr	LATB, #7
1:
	btg	LATB, #7

	bclr	LATB, #9	; right LED goes red during reset
	mov	#0x0018, W0	; reset, host mode, no SOF
	mov	W0, U1CON
	mov	#50, W0		; reset lasts 50ms
	rcall	USB_WAIT
	bclr	U1CON, #USBRST	; end reset
	bset	LATB, #9

	; Microchip's documentation and example code make no mention of
	; low-speed keep-alive pulses, but oscilloscope testing of the
	; physical hardware shows that the chip generates them instead of
	; SOFs when SOFEN is set in low-speed mode, which is convenient.
	; Keep-alives look like 1.3us pulses of SE0 repeated at 1ms
	; intervals.

	bset	U1CON, #SOFEN	; start SOF/keep-alive so device won't sleep

	mov	#100, W0	; wait 100ms for device to recover from reset
	rcall	USB_WAIT

	mov	W14, W0		; null out IRP in the stack frame
	repeat	#((IRP_SIZE+8)/2-1)
	clr	[W0++]
	add	W14, #IRP_SIZE, W1	; set buffer address after IRP
	mov	W1, [W14+4]
	mov	W14, ep0_irp	; point endpoint 0 at IRP (still inactive)
	mov	#ep0, W0	; endpoint 0 is entirety of endpoint list
	mov	W0, endpoint_ll

 	mov	#(1<<DETACHIF), W0	; ignore seeming detaches up to now
 	mov	W0, U1IR
	bclr	U1OTGIE, #T1MSECIE	; 1ms or SOF interrupts, not both
	mov	#0x0F, W0	; enable transfer, SOF, error, and detach
	mov	W0, U1IE
	setm	U1EIE		; enable all types of error interrupts

	; set device address to 1

	; SETUP packet looks like 00 05 01 00 00 00 00 00
	; W1 is start of buffer, from above
	mov	#0x0500, W0	; set address, host to device
	mov	W0, [W1++]
	mov	#1, W0		; address will be 1
	mov	W0, [W1++]
	clr	[W1++]		; "wIndex" zero
	clr	[W1++]		; "wLength" zero
	rcall	do_ctrl_z_transaction

	mov	#5, W0		; wait 5ms (spec minimum 2ms) for recovery
	rcall	USB_WAIT

	; record the device's new address of 1 (was 0, so just set low bit)
	bset.b	ep0_address, #0

	; get first eight bytes of device descriptor

	; SETUP packet looks like 80 06 00 01 00 00 08 00
	add	W14, #IRP_SIZE, W1	; reset W1 to start of buffer
	mov	#0x0680, W0	; get descriptor, device to host
	mov	W0, [W1++]
	mov	#0x0100, W0	; device descriptor, index 0
	mov	W0, [W1++]
	clr	[W1++]		; language ID zero
	mov	#8, W0		; 8 bytes of response desired
	mov	W0, [W1++]
	mov	W0, ep0_max_packet	; allow it all in one packet
	mov	#16, W2		; 8 bytes setup, 8 bytes response
	rcall	do_ctrl_r_transaction

	mov	#5, W0		; wait 5ms for extra safety
	rcall	USB_WAIT

	; extract information from the first eight bytes of descriptor

	clr	W0		; need high byte to be zero later
	mov.b	[W14+IRP_SIZE+15], W0	; max packet size from eighth byte
	mov	W0, ep0_max_packet	; set new max packet size
	mov.b	[W14+IRP_SIZE+8], W0	; descriptor length from first byte
	mov.b	W0, [W14+IRP_SIZE+6]	; update setup packet with new length
	; note we leave descriptor length in W0

	; get device descriptor

	; SETUP packet looks like 80 06 00 01 00 00 xx 00
	; where xx is length, which will probably always be 0x12, but we
	; don't want to ask for that on the first try because we want to
	; know the max packet size before asking for more than 8 bytes
	add	W0, #8, W2	; buffer is descriptor plus 8 bytes
	rcall	do_ctrl_r_transaction

	mov	#5, W0		; wait 5ms for extra safety
	rcall	USB_WAIT

	add	W14, #(IRP_SIZE+8), W0	; save copy of device descriptor
	mov	#saved_dev_desc, W1
	repeat	#8
	mov	[W0++], [W1++]

	mov	#handle(catch_tpl_match), W1
	rcall	TRY

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; LINKER INSERTS TARGETED DEVICE LIST HERE ;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Recognize hubs (device class 9) and run the "driver" for them, which just
; blinks a light until the device is disconnected.  This is an example of
; the kind of thing that the linker will insert; other similar sections from
; other files will also be inserted here, according to their priority.
; The hub detection is priority 10, quite high, so it'll appear before most
; other checks.
.pushsection tdl10, code
	mov	#handle(complain_about_hub), W4
	mov	#0xFF09, W5
	rcall	TPL_MATCH_DEVICE_CLASS
.popsection

.pushsection mtbl, code
	; code 1240:  simulate USB hub insertion
	.word	0x1240, complain_about_hub
.popsection

.section _tpl_mid, code

	rcall	TRIED

	; we get to this point if we haven't recognized and handled the
	; device just on the basis of its device descriptor

	; loop over configurations
	clr	current_conf
config_desc_loop:

	; get first 8 bytes of configuration descriptor

	; SETUP packet looks like 80 06 xx 02 00 00 yy 00
	; where xx is current config descriptor index and yy is max packet
	; size
	add	W14, #IRP_SIZE, W1	; reset W1 to start of buffer
	mov	#0x0680, W0	; get descriptor, device to host
	mov	W0, [W1++]
	mov	current_conf, W0	; config descriptor, current index
	bset	W0, #9
	mov	W0, [W1++]
	clr	[W1++]		; language ID zero
	mov	#8, W0		; at most 8 bytes desired
	mov	W0, [W1++]
	add	W0, #8, W2	; 8 bytes setup, plus response size
	rcall	do_ctrl_r_transaction

	mov	#5, W0		; wait 5ms for extra safety
	rcall	USB_WAIT

	; extract information from the first bytes of descriptor

	mov	[W14+IRP_SIZE+10], W0	; package length in bytes 2-3
	mov	#MAX_DESCRIPTOR_SIZE, W2	; check for overlong
	cp	W0, W2
	bra	gtu, SKIP_PAST_CONFIGURATION
	mov	#8, W2		; check for whole thing in last transaction
	cp	W0, W2
	bra	leu, 1f			; if we have it all, don't try again
	mov	W0, [W14+IRP_SIZE+6]	; update setup packet with new length
	; note we leave descriptor package length in W0

	; get full configuration descriptor package

	; SETUP packet looks like 80 06 xx 02 00 00 yy yy
	; where xx is current config descriptor index and yyyy is length of
	; the descriptor package
	add	W0, #8, W2	; buffer is descriptor plus 8 bytes
	rcall	do_ctrl_r_transaction

	mov	#5, W0		; wait 5ms for extra safety
	rcall	USB_WAIT

1:
	add	W14, #(IRP_SIZE+8), W0	; save copy of config descriptor
	mov	#saved_conf_desc, W1
	repeat	#4
	mov	[W0++], [W1++]

	mov.b	[W14+IRP_SIZE+13], W0	; specially save config index
	mov.b	WREG, saved_conf_index

	; loop over interfaces
	clr	current_iface
iface_desc_loop:

	; eat descriptor, whatever kind it is, at the head of the buffer
	add	W14, #(IRP_SIZE+8), W1	; point W1 at destination of move
	clr	W0		; point W0 at (possibly unaligned!) source
	mov.b	[W1], W0
	add	W1, W0, W0
	; repeat count reflects the most bytes the result could possibly be
	repeat	#(MAX_DESCRIPTOR_SIZE-9-1)
	mov.b	[W0++], [W1++]	; copy, a byte at a time

	; loop until we are looking at an interface descriptor
	mov.b	[W14+IRP_SIZE+9], W0	; get descriptor type
	cp.b	W0, #4			; is it 4 (interface)?
	bra	nz, iface_desc_loop	; if not, go back and eat it too

	mov.b	[W14+IRP_SIZE+10], W0	; specially save interface index
	mov.b	WREG, saved_iface_index

	; TIL should THROW with driver address in W4 on match
	mov	#handle(catch_tpl_match), W1
	rcall	TRY

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; LINKER INSERTS TARGETED INTERFACE LIST HERE ;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.section _tpl_done, code

	; we get to this point if we haven't recognized and handled the
	; device on the basis of the current interface descriptor

.global SKIP_PAST_INTERFACE
SKIP_PAST_INTERFACE:

	rcall	TRIED

	; end loop over interfaces
	inc	current_iface		; bump counter
	mov.b	saved_conf_desc+4, WREG	; get limit from saved descriptor
	cp.b	current_iface		; compare
	bra	ltu, iface_desc_loop	; try again if not finished

.global SKIP_PAST_CONFIGURATION
SKIP_PAST_CONFIGURATION:

	; end loop over configurations
	inc	current_conf		; bump counter
	mov.b	saved_dev_desc+17, WREG	; get limit from saved descriptor
	cp.b	current_conf		; compare
	bra	ltu, config_desc_loop	; try again if not finished

	; if we reach this point, we can't handle the device.  Blink
	; long-short-short (Morse "D" for "device unsupported") until
	; it is removed.  Global label because it may be useful in TPL for
	; pre-emptively rejecting devices we know we can't support.
.global COMPLAIN_ABOUT_DEVICE
COMPLAIN_ABOUT_DEVICE:
	mov	#0xFFA8, W1	; long-short-short blink pattern
	bra	finish_with_blinking

.pushsection mtbl, code
	; code 3627:  simulate unsupported USB device insertion
	.word	0x3627, COMPLAIN_ABOUT_DEVICE
.popsection


complain_about_hub:
	mov	#0xFFAA, W1	; sets of four red flashes, Morse H for "hub"

finish_with_blinking:
	rcall	LEDBLINK_INIT
	clr	LEDBLINK_RB9
	mov	W1, LEDBLINK_TRIS9

finish_handle_attach:
	pwrsav	#1
	rcall	USB_TEST_ATTACHED
	bra	nz, finish_handle_attach

; these are useful jump targets elsewhere, so make them global
.global ULNK_RETURN, RETURN_INSN
ULNK_RETURN:
	ulnk
RETURN_INSN:
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Process transaction in foreground"

.section .text

; USB_WAIT_ON_IRP is the core subroutine for handling a USB transaction in
; the foreground.  It takes configuration flags (OR of IRPFM_x constants) in
; W1, buffer size in W2, endpoint pointed to by W4, IRP pointed to by W5;
; trashes W0 and W3.  Set bit UF_MIDI_BKGND in USB_FLAGS to make it run MIDI
; background tasks while waiting.  The buffer, for control transactions,
; needs to have space for the setup (always 8 bytes) as well as the
; response; and all buffers that the hardware will write should also have at
; least BUFFER_SAFETY_MARGIN extra bytes at the end to accommodate the
; apparent hardware bug that makes it sometimes overrun buffers.

; The other entry points basically provide default values or tweaks for
; USB_WAIT_ON_IRP.  do_transaction points W4 at ep0 (for control transfers)
; and W5 at the stack frame.  do_ctrl_r_transaction and
; do_ctrl_w_transaction are for control read and control writes
; respectively, supplying suitable flag values in W1.  do_ctrl_z_transaction
; is for a zero-length control transaction (SETUP only), which is handled as
; a write of zero length.

do_ctrl_z_transaction:
	mov	#8, W2	; 8 bytes setup, no response

do_ctrl_w_transaction:
	mov	#IRPFM_UOWN|IRPFM_CTRL_W, W1
	bra	do_transaction

do_ctrl_r_transaction:
	mov	#IRPFM_UOWN|IRPFM_CTRL_R, W1

do_transaction:
	mov	#ep0, W4	; W4 and W5 values for CTRL transactions
	mov	W14, W5

; entry point for use by device drivers
.global USB_WAIT_ON_IRP
USB_WAIT_ON_IRP:
	inc2	W4, W4		; we actually want it pointing at flags
	mov	#5, W3		; error retry count

3:
	mov	W1, [W5]	; put the transaction flags in IRP
	mov	W2, [W5+2]	; set buffer size
	clr	W0		; reset buffer fill point
	mov	W0, [W5+6]
	mov	W5, [W4+4]	; point endpoint at IRP

1:
	btsc	USB_FLAGS, #UF_MIDI_BKGND
	rcall	MIDI_BACKGROUND_SAFE

	setm	TOKEN_STORE	; we have nothing else to do
	pwrsav	#1		; wait for interrupt

	rcall	USB_TEST_ATTACHED	; make sure we still have a device
	bra	z, THROW

	btst	[W5], #IRPF_UOWN	; check for transaction complete
	bra	nz, 1b

	btst	[W5], #IRPF_ERROR	; check for transaction error
	bra	z, RETURN_INSN		; done if no error

	dec	W3, W3		; check for too many errors
	bra	z, THROW

	bclr	[W4], #EPF_STALLED	; ANINSUTOORU!
	clr	W0
	mov	W0, [W4+10]
	bra	3b

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Support for targeted peripherals list"

; Working register use within the TPL is as follows.  Set appropriate
; registers before calling a support routine, and preserve the registers
; indicated.

; W4  - driver address (support routine argument)
; W5  - device class and subclass (support routine argument)
; W6  - device subclass and protocol (support routine argument)

; W14 - stack frame, points at IRP, W14+16 points at descriptor, preserve
; W15 - stack pointer, preserve

; It is intended that TPL entries should THROW with the driver address in W4
; in case of match; the handler in effect during the TPL will then jump to
; that address.  A plain jump would be okay too, but then the driver at the
; end of the jump should probably call TRIED to discard the TRY block that
; established this special handler.

; TPL-matching functions expect the device driver address in W4 and on
; match, they do a THROW, which is caught here, and branches to the address
; in W4 after turning off the LEDs.
catch_tpl_match:
	bset	TRISB, #7	; turn off LEDs
	bset	TRISB, #9

; global so we can reuse it elsewhere
.global GOTO_W4_INSN
GOTO_W4_INSN:
	goto	W4		; go run the driver

; THROW if class and subclass of the saved device descriptor match class
; (low byte) and subclass (high byte) in W5; 0xFF is a wildcard matching all
.global TPL_MATCH_DEVICE_CLASS
TPL_MATCH_DEVICE_CLASS:
	mov	saved_dev_desc+4, W1	; get class and subclass

tpl_match_internal:
	mov	W5, W0			; copy matching pattern
	rcall	check_class_wildcard	; check class, prepare for subclass
	bra	nz, 1f
	swap	W0

	swap	W1			; get subclass
	rcall	check_class_wildcard	; check subclass
	bra	z, THROW
1:
	return

; THROW if class and subclass of current interface descriptor match class
; and subclass in W5, as TPL_MATCH_INTERFACE_CLASS below, but also low byte
; of W6 matches the protocol (0xFF is wildcard).
.global TPL_MATCH_CLASS_AND_PROTOCOL
TPL_MATCH_CLASS_AND_PROTOCOL:
	mov.b	W6, W0
	mov.b	[W14+IRP_SIZE+8+7], W1
	rcall	check_class_wildcard
	bra	nz, RETURN_INSN

	; FALL THROUGH, tail call

; THROW if class and subclass of the current interface descriptor match
; class (low byte) and subclass (high byte) in W5; 0xFF is a wildcard
; matching all
.global TPL_MATCH_INTERFACE_CLASS
TPL_MATCH_INTERFACE_CLASS:
	mov.b	[W14+IRP_SIZE+8+6], W1	; get class
	swap	W1
	mov.b	[W14+IRP_SIZE+8+5], W1	; get subclass
	bra	tpl_match_internal	; reuse the code

; utility function for matching device, interface, etc.  classes.  Returns
; "equal" comparison result if low byte of W0 is 0xFF, or if low byte of W0
; is equal to low byte of W1.  Trashes low bytes of W0 and W2, leaves high
; bytes alone.  The idea is that W0 comes from the TPL, representing what
; classes or whatever we can handle, with 0xFF as a wildcard value; W1 comes
; from the USB device representing what the device actually is; and we get
; an "equal" return if it's a device we think we can handle.
check_class_wildcard:
	setm.b	W2	; get all ones in W2 for comparison
	cpsne.b	W0, W1	; if it's not an exact match...
	setm.b	W0	; ..then don't force the pattern to wildcard
	cp.b	W0, W2	; now see if it's a wildcard
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Support for device drivers"

; Configure the device for the descriptor currently in the caller's lnk/ulnk
; stack variable frame *and remove this stack frame*; caller must create a
; new one afterward if desired.  This unusual calling convention is because
; of the way the USB session handler invokes drivers with a goto instead of
; a call, leaving its own stack frame in place.

; Invoke with W8 pointing at an array of endpoint data structures,
; and W9 containing the number of such structures in the array.  This
; function will set them up according to the endpoint descriptors for the
; current interface, up to the maximum number specified in W9, and add them
; to the driver's linked list.  The W8 register is left pointing after the
; last endpoint actually set up.

.global USB_CONFIGURE_DEVICE
USB_CONFIGURE_DEVICE:
	mov.b	[W14+IRP_SIZE+8+4], W2	; get number of endpoints
	cpslt.b	W2, W9		; reduce W2 to at most what caller asked for
	mov.b	W9, W2
	clr.b	WREG2H	

	add	W14, #(IRP_SIZE+8), W3	; W3 will point at current descriptor
1:
	cp0	W2		; loop while W2>0
	bra	z, 1f

2:
	ze	[W3], W0	; advance W3 to next descriptor
	add	W3, W0, W3

	; decode endpoint descriptor

	mov.b	[W3+1], W0	; is it an endpoint?
	cp.b	W0, #5
	bra	nz, 2b		; if not, look further

	clr	[W8++]		; clear endpoint link field

	mov.b	[W3+2], W0	; get endpoint address bit
	lsr	W0, #7, W0
	mov.b	W0, [W8++]	; store that in low byte of flags
	mov.b	[W3+3], W0	; put bmAttributes in high byte of flags
	mov.b	W0, [W8++]

	mov.b	[W3+2], W0	; put endpoint number in data structure
	and	W0, #0xF, W0
	mov.b	W0, [W8++]
	mov	#1, W0
	mov.b	W0, [W8++]	; address is constant value 1

	clr	[W8++]		; clear IRP list
	
	mov.b	[W3+5], W0	; put max packet size in data structure
	swap	W0		; a byte at a time because unaligned source
	mov.b	[W3+4], W0
	mov	W0, [W8++]

	clr	[W8++]		; clear NAK count

	mov.b	[W3+6], W0	; put interval in data structure
	clr.b	WREG0H
	mov	W0, [W8++]

	; add this endpoint to the driver's endpoint list
	sub	W8, #ENDPOINT_SIZE, W0
	mov	#endpoint_ll, W1
	rcall	LL_APPEND_ATOMIC

	dec	W2, W2		; end loop
	bra	1b

1:
	; set device configuration

	; SETUP packet looks like 00 09 xx 00 00 00 00 00
	; where xx is configuration request value from byte 5 of
	; the configuration descriptor
	add	W14, #IRP_SIZE, W1	; reset W1 to start of buffer
	mov	#0x0900, W0	; set configuration, host to device
	mov	W0, [W1++]
	repeat	#2		; zero out rest of request
	clr	[W1++]
	mov.b	saved_conf_index, WREG	; get configuration number
	mov.b	W0, [W14+IRP_SIZE+2]	; put it in buffer

	pop	W6	; remove return address
	pop	W6

	rcall	do_ctrl_z_transaction	; THROWs on failure
	ulnk		; on success discard our stack frame

	goto	W6

; do a SET_PROTOCOL operation for protocol 0 ("boot") on HIDs
.global USB_SET_BOOT_PROTOCOL
USB_SET_BOOT_PROTOCOL:
	lnk	#(IRP_SIZE+8)	; IRP, 8 bytes SETUP packet

	; set up IRP
	mov	W14, W1
	clr	[W1++]		; flags will be set later
	mov	#8, W0		; 8 bytes setup, no reply
	mov	W0, [W1++]
	add	W14, #IRP_SIZE, W0	; buffer immediately after IRP
	mov	W0, [W1++]
	clr	[W1++]		; nothing sent yet

	; SETUP packet looks like 21 0B 00 00 xx 00 00 00
	; where xx is the interface number
	mov	#0x0B21, W0	; request type and request
	mov	W0, [W1++]
	clr	[W1++]		; protocol 0, "boot"
	mov.b	saved_iface_index, WREG	; index we saved from descriptor
	mov.b	W0, [W1++]
	clr.b	[W1++]		; high byte of index always zero
	clr	[W1++]		; reply length zero

	rcall	do_ctrl_z_transaction
	bra	ULNK_RETURN

; do a SET_REPORT operation for HIDs, with a single byte of data from W2 low
.global USB_SET_REPORT
USB_SET_REPORT:
	; IRP, 8 bytes SETUP, 1 byte report, safety margin, round to word
	lnk	#((IRP_SIZE+9+BUFFER_SAFETY_MARGIN+1)&~1)

	; set up IRP
	mov	W14, W1
	clr	[W1++]		; flags will be set later
	mov	#9, W0		; 8 bytes setup, 1 byte data
	mov	W0, [W1++]
	add	W14, #IRP_SIZE, W0	; buffer immediately after IRP
	mov	W0, [W1++]
	clr	[W1++]		; nothing sent yet

	; SETUP packet looks like 21 09 00 02 xx 00 01 00
	; where xx is the interface number
	; followed by the one byte of data
	mov	#0x0921, W0	; request type and request
	mov	W0, [W1++]
	mov	#0x0200, W0	; report type 2 ("output"), id 0
	mov	W0, [W1++]
	mov.b	saved_iface_index, WREG	; index we saved from descriptor
	mov.b	W0, [W1++]
	clr.b	[W1++]		; high byte of index always zero
	mov	#1, W0		; reply length 1
	mov	W0, [W1++]
	mov	W2, [W1++]	; put the report value in the buffer
	mov	#9, W2		; buffer is 8 byte SETUP plus 1 byte report

	rcall	do_ctrl_w_transaction
	bra	ULNK_RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "General USB APIs"

; Test whether USB device is attached.  Returns Z flag set iff not attached.
; If disconnected, stores error code on the current endpoint if any, and
; sets error bit on the current endpoint's current IRP if we own it
; FIXME maybe disable interrupts while touching internal data structures?
.global USB_TEST_ATTACHED
USB_TEST_ATTACHED:
	rcall	CHECK_VBUS
	btst	USB_FLAGS, #UF_ATTACHED	; check our current guess
	bra	nz, confirm_attached

confirm_detached:
	mov	current_endpoint, W0	; see if we have a current endpoint
	cp0	W0 
	bra	z, 1f

	add	W0, #12, W0		; set error code
	setm	[W0]
	mov	[W0-6], W0		; get IRP

	cp0	W0			; see if we have an IRP
	bra	z, 1f		
	btst	[W0], #IRPF_UOWN	; see if we own it
	bra	z, 1f

	bset	[W0], #IRPF_ERROR	; mark it erroneous
	bclr	[W0], #IRPF_UOWN	; return it to foreground

1:
	bclr	USB_FLAGS, #UF_ATTACHED	; remember we are detached
	bclr	USB_FLAGS, #UF_LOW_SPEED	; go full-speed on detach

	bclr	U1CON, #SOFEN		; stop sending SOFs/keep-alives
	bset	U1OTGIE, #T1MSECIE	; want 1ms interrupts if not SOFEN
	bclr	U1ADDR, #LSPDEN		; return hardware to full speed mode
	bclr	U1EP0, #LSPD

.global Z_RETURN
Z_RETURN:
	bset	SR, #Z
	return

confirm_attached:
	bset	USB_FLAGS, #UF_ATTACHED
.global NZ_RETURN
NZ_RETURN:
	bclr	SR, #Z
	return

; Test whether USB device is low-speed.  Returns Z flag set iff not
; low-speed.  Also updates driver-internal flag to reflect this
; information.
.global USB_TEST_SPEED
USB_TEST_SPEED:
confirm_full_speed:
	rcall	wait_and_test_jstate	; must NOT see JSTATE three times
	bra	z, confirm_low_speed
	rcall	wait_and_test_jstate
	bra	z, confirm_low_speed
	rcall	wait_and_test_jstate
	bra	z, confirm_low_speed

	bclr	USB_FLAGS, #UF_LOW_SPEED
	bclr	U1ADDR, #LSPDEN
	bclr	U1EP0, #LSPD
	bra	Z_RETURN

confirm_low_speed:
	rcall	wait_and_test_jstate	; must see JSTATE three times
	bra	nz, confirm_full_speed
	rcall	wait_and_test_jstate
	bra	nz, confirm_full_speed
	rcall	wait_and_test_jstate
	bra	nz, confirm_full_speed

	bset	USB_FLAGS, #UF_LOW_SPEED
	bset	U1ADDR, #LSPDEN
	bset	U1EP0, #LSPD
	bra	NZ_RETURN

wait_and_test_jstate:
	repeat	#(USB_BUS_SETTLING_TIME-1)
	nop
	btst	U1CON, #JSTATE
	return

; wait for W0 number of 1ms ticks
.global USB_WAIT
USB_WAIT:
1:
	btsc	USB_FLAGS, #UF_MIDI_BKGND
	rcall	MIDI_BACKGROUND_SAFE

	pwrsav	#1
	btst	SOFT_INT_FLAGS, #SI_1MS
	bra	z, 1b
	bclr	SOFT_INT_FLAGS, #SI_1MS
	dec	W0, W0
	bra	gtu, 1b
	return

; Wait for W0 number of 1ms ticks.  Unlike USB_WAIT above, this uses a timer
; that continues running in the background and attempts to make up for lost
; time, so repeated calls to USB_LOOP_WAIT with X milliseconds will end up
; returning X milliseconds apart even if the foreground takes more than a
; millisecond between the return and the next call.  It's intended to
; control the loop of an interrupt endpoint, hence the name.
.global USB_LOOP_WAIT
USB_LOOP_WAIT:
	add	loop_wait_ms
	bra	nn, 1f
	clr	loop_wait_ms
1:
	cp0	loop_wait_ms
	bra	le, RETURN_INSN

	btsc	USB_FLAGS, #UF_MIDI_BKGND
	rcall	MIDI_BACKGROUND_SAFE

	pwrsav	#1
	bra	1b

; Return NZ once every W0 ticks; does not wait
.global USB_LOOP_CHECK
USB_LOOP_CHECK:
	cp0	loop_wait_ms
	bra	gt, Z_RETURN

	add	loop_wait_ms
	bra	nn, NZ_RETURN

	clr	loop_wait_ms
	bra	NZ_RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Try to send a packet"

; send_next_token is an internal routine called within the ISR to attempt
; sending another token (conditional on whether we have an eligible one at
; the moment, and enough budget in TOKEN_STORE).  It's pulled out into a
; separate routine both to make structuring the ISR easier and so that we
; can call it in USB_POKE.

; USB_POKE is a user-visible interface to send_next_token, allowing the
; foreground to give the driver a chance at sending a token without waiting
; for the next interrupt.  This can improve throughput, as well as smoothing
; out the bursts of packets that might otherwise happen in polled bulk
; transfer situations like USB-MIDI.

.global USB_POKE

USB_POKE:
	bclr	IEC5, #USB1IE	; do all this with USB interrupt disabled

	cp0	current_endpoint
	bra	nz, 1f

	mov	endpoint_ll, W2		; start over with first endpoint
	mov	W2, current_endpoint
1:

	mov	current_endpoint, W2
	rcall	send_next_token

	bset	IEC5, #USB1IE	; allow USB interrupts again
	return

; W1 will point at IRP, W2 at endpoint.  On call to this routine, W2 should
; be pointing at the link field of current_endpoint, but it is soon
; incremented to point at the flags field.

send_next_token:
	btst	USB_FLAGS, #UF_BUSY	; cannot send if token in progress
	bra	nz, RETURN_INSN

	cp0	current_endpoint	; do we have another endpoint?
	bra	z, RETURN_INSN

	btst	[++W2], #EPF_STALLED	; is it stalled?
	bra	z, 1f

try_next_endpoint:
	mov	[--W2], W2
	mov	W2, current_endpoint
	bra	send_next_token

1:
	mov	[W2+4], W1		; get the endpoint's IRP
	cp0	W1			; check it's non-empty
	bra	z, try_next_endpoint

	btst	[W1], #IRPF_UOWN	; skip endpoint if we don't own IRP
	bra	z, try_next_endpoint

	btst	[W1], #IRPF_CTRL	; handle CTRL transaction
	bra	z, try_sending_intr_bulk

	; CTRL IRP

	btst	USB_FLAGS, #UF_SENT_CTRL	; just one allowed per frame
	bra	nz, try_next_endpoint

	cp0	TOKEN_STORE		; consume a token from the store
	bra	z, RETURN_INSN
	dec	TOKEN_STORE

	mov	[W1+6], W0		; are we sending SETUP?
	cp0	W0
	bra	nz, try_sending_ctrl_data

	; we are sending a CTRL SETUP

	btst	bdt_tx_stat, #15	; make sure BDT isn't occupied
	bra	nz, RETURN_INSN		; if it is, too bad

	bclr	[W2], #EPF_DATA1	; set DATA0

	mov	[W1+4], W0	; write buffer address into BDT
	mov	W0, bdt_tx_addr
	mov	#0x8808, W0	; hardware owns it, DATA0, DTS, 8 bytes
	mov	W0, bdt_tx_stat

	; save the current IRP and endpoint addresses
	mov	W1, tx_irp
	dec2	W2, W0
	mov	W0, tx_ep

	mov	#0x004D, W0	; set endpoint control reg for CTRL transfer
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPD
	mov	W0, U1EP0

	mov	[++W2], W3	; address in high byte, endpoint in low
	mov.b	WREG3H, WREG	; set address/speed register
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPDEN
	mov	W0, U1ADDR

	mov	#0x00D0, W0	; send the token
	ior.b	WREG3L, WREG
	mov	W0, U1TOK

	bra	finished_sending_ctrl

try_sending_ctrl_data:
	mov	[W1+6], W0	; do we have data remaining?
	mov	[W1+2], W4
	sub	W4, W0, W4
	bra	z, sending_ctrl_ack	; if no data then we should ACK
	btst	[W1], #IRPF_ACK		; or if we decided to before
	bra	nz, sending_ctrl_ack

	; we are sending or receiving CTRL data

	mov	[W2+6], W0	; limit packet size to max
	cpslt	W4, W0
	mov	W0, W4

	mov	#bdt_rx_stat, W3	; put BDT entry address in W3
	btsc	[W1], #IRPF_WRITE
	mov	#bdt_tx_stat, W3

	btst	[W3++], #15	; make sure BDT isn't occupied
	bra	nz, RETURN_INSN	; if it is, too bad

	; at this point W1 points at IRP flags field, W2 points at endpoint
	; flags field, W3 points at BDT address field, W4 is packet size,
	; W5 will be fill point

	mov	[W1+4], W0	; write buffer address into BDT
	mov	[W1+6], W5
	add	W0, W5, W0	; adjusted for portion already filled
	mov	W0, [W3--]
	mov	#0x8800, W5	; hardware owns it, DTS
	btsc	[W2], #EPF_DATA1	; assign DATAx bit
	bset	W5, #14
	add	W4, W5, W0	; add in the packet size
	mov	W0, [W3]	; write low word of BDT entry

	; save the current IRP and endpoint addresses
	add	W3, #soft_bdt_offset, W5	; W5 becomes soft BDT entry
	mov	W1, [W5++]
	dec2	W2, W0
	mov	W0, [W5--]

	mov	#0x004D, W0	; set endpoint control reg for CTRL transfer
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPD
	mov	W0, U1EP0

	mov	[++W2], W3	; address in high byte, endpoint in low
	mov.b	WREG3H, WREG	; set address/speed register
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPDEN
	mov	W0, U1ADDR

	mov	#0x0010, W0	; send the token
	btss	[W1], #IRPF_WRITE
	bset	W0, #7
	ior.b	WREG3L, WREG
	mov	W0, U1TOK

	bra	finished_sending_ctrl

sending_ctrl_ack:
	; now we know we are sending or receiving a CTRL ACK ("status stage")

	bset	[W2], #EPF_DATA1	; set DATA1
	bset	[W1], #IRPF_ACK		; set ACK in case we didn't before

	mov	#bdt_tx_stat, W3	; put BDT entry address in W3
	btsc	[W1], #IRPF_WRITE
	mov	#bdt_rx_stat, W3	; note packet is in reverse direction

	btst	[W3++], #15	; make sure BDT isn't occupied
	bra	nz, RETURN_INSN	; if it is, too bad

	; at this point W1 is IRP flags field, W2 is endpoint flags field,
	; W3 is BDT address field

	mov	[W1+4], W0	; write buffer address into BDT
	mov	[W1+6], W5
	add	W0, W5, W0	; adjusted for portion already filled
	mov	W0, [W3--]
	mov	#0xC800, W0	; hardware owns it, DATA1, DTS, zero bytes
	mov	W0, [W3]	; write low word of BDT entry

	; save the current IRP and endpoint addresses
	add	W3, #soft_bdt_offset, W5
	mov	W1, [W5++]
	dec2	W2, W0
	mov	W0, [W5--]

	mov	#0x004D, W0	; set endpoint control reg for CTRL transfer
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPD
	mov	W0, U1EP0

	mov	[++W2], W3	; address in high byte, endpoint in low
	mov.b	WREG3H, WREG	; set address/speed register
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPDEN
	mov	W0, U1ADDR

	mov	#0x0010, W0	; send the token
	btsc	[W1], #IRPF_WRITE	; note reverse direction
	bset	W0, #7
	ior.b	WREG3L, WREG
	mov	W0, U1TOK

	; bra	finished_sending_ctrl
	; FALL THROUGH

finished_sending_ctrl:
	bset	USB_FLAGS, #UF_SENT_CTRL	; no more CTRL this frame
finished_sending_token:
.if UF_BUSY_WATCHDOG_TIME>0
	mov	#UF_BUSY_WATCHDOG_TIME, W0	; reset watchdog
	mov	W0, uf_busy_watchdog
.endif
 	bset	USB_FLAGS, #UF_BUSY		; no token at all for a while
.ifdef PULSE_PIN14_ON_BUSY
	bset	LATB, #5
.endif
	return

try_sending_intr_bulk:
	cp0	TOKEN_STORE		; consume a token from the store
	bra	z, RETURN_INSN
	dec	TOKEN_STORE

	; INTR or BULK IRP

	mov	[W1+6], W0	; figure out how much data remains to send
	mov	[W1+2], W4
	sub	W4, W0, W4
	bra	z, RETURN_INSN	; skip if nothing to send

	mov	[W2+6], W0	; limit packet size to max
	cpslt	W4, W0
	mov	W0, W4

	mov	#bdt_rx_stat, W3	; put BDT entry address in W3
	btsc	[W1], #IRPF_WRITE
	mov	#bdt_tx_stat, W3

	btst	[W3++], #15	; make sure BDT isn't occupied
	bra	nz, RETURN_INSN	; if it is, too bad

	; at this point W1 points at IRP flags field, W2 points at endpoint
	; flags field, W3 points at BDT address field, W4 is packet size,
	; W5 will be fill point

	mov	[W1+4], W0	; write buffer address into BDT
	mov	[W1+6], W5
	add	W0, W5, W0	; adjusted for portion already filled
	mov	W0, [W3--]
	mov	#0x8800, W5	; hardware owns it, DTS
	btsc	[W2], #EPF_DATA1	; assign DATAx bit
	bset	W5, #14
	add	W4, W5, W0	; add in the packet size
	mov	W0, [W3]	; write low word of BDT entry

	; save the current IRP and endpoint addresses
	add	W3, #soft_bdt_offset, W5
	mov	W1, [W5++]
	dec2	W2, W0
	mov	W0, [W5--]

	mov	#0x005D, W0	; set control reg for non-CTRL transfer
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPD
	mov	W0, U1EP0

	mov	[++W2], W3	; address in high byte, endpoint in low
	mov.b	WREG3H, WREG	; set address/speed register
	btsc	USB_FLAGS, #UF_LOW_SPEED
	bset	W0, #LSPDEN
	mov	W0, U1ADDR

	mov	#0x0010, W0	; send the token
	btss	[W1], #IRPF_WRITE
	bset	W0, #7
	ior.b	WREG3L, WREG
	mov	W0, U1TOK

	bra	finished_sending_token	; shared tail

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Interrupt routine"

.section .isr, code
; USB multiplex interrupt
.global __USB1Interrupt
__USB1Interrupt:
	push	W0
	push	W1
	push	W2
	push	W3
	push	W4
	push	W5
;	push	RCOUNT	; uncomment if we reintroduce "repeat" in the ISR
	bclr	IFS5, #USB1IF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; attach interrupt:  go into state 1 (we expect to be currently in 0)
6:
	btst	U1IR, #ATTACHIE
	bra	z, 6f
	btst	U1IR, #ATTACHIF
	bra	z, 6f

	bset	USB_FLAGS, #UF_ATTACHED

	; Microchip says attach interrupt is "level triggered."  That
	; apparently means it'll keep happening as long as a device is
	; attached and the interrupt is enabled.  So we must disable it when
	; we process the interrupt.
	bclr	U1IE, #ATTACHIE
	mov	#(1<<ATTACHIF)|(1<<DETACHIF), W0
	mov	W0, U1IR
	bset	U1IE, #DETACHIE

.ifdef LEDS_ON_USB_ATTACHED
	bclr	LATB, #7	; LEDs red
	bclr	LATB, #9
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; detach interrupt:  go into state 0
6:
	btst	U1IE, #DETACHIE
	bra	z, 6f
	btst	U1IR, #DETACHIF
	bra	z, 6f

	bclr	USB_FLAGS, #UF_ATTACHED

	; Microchip doesn't say so but we know from experiments with the
	; hardware that the detach interrupt is also one of these "level
	; triggered" interrupts and it must be disabled and acknowledged
	; every time it happens, else the ISR will repeat in a loop.
	bclr	U1IE, #DETACHIE
	mov	#(1<<ATTACHIF)|(1<<DETACHIF), W0
	mov	W0, U1IR
	bset	U1IE, #ATTACHIE

.ifdef LEDS_ON_USB_ATTACHED
	bset	LATB, #7	; LEDs green
	bset	LATB, #9
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; start of frame:  reset work list to start, try sending a token
6:
	btst	U1IE, #SOFIE
	bra	z, 6f
	btst	U1IR, #SOFIF
	bra	z, 6f

	mov	#(1<<SOFIF), W0
	mov	W0, U1IR

	rcall	handle_1ms_tick

.ifdef PULSE_PIN14_ON_SOF
	bset	LATB, #5	; test point goes high on this interrupt
.endif

	bclr	USB_FLAGS, #UF_SENT_CTRL	; allow a fresh CTRL token

	mov	endpoint_ll, W2		; start over with first endpoint
	mov	W2, current_endpoint

	bra	send_next_in_isr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; 1ms interrupt
6:
	btst	U1OTGIR, #T1MSECIF
	bra	z, 6f

	mov	#(1<<T1MSECIF), W0
	mov	W0, U1OTGIR

	btst	U1CON, #SOFEN	; ignore 1ms if SOF AND its int are enabled
	bra	z, 1f
	btst	U1IE, #SOFIE
	bra	nz, 6f
1:

	rcall	handle_1ms_tick
.pushsection *, code
handle_1ms_tick:
	bset	SOFT_INT_FLAGS, #SI_1MS	; set flag for USB_WAIT

	dec	loop_wait_ms	; decrement counter for USB_LOOP_WAIT
	mov	#-10000, W0	; and don't let it go below -10 seconds
	cp	loop_wait_ms
	bra	ge, 1f
	mov	W0, loop_wait_ms
1:

.if UF_BUSY_WATCHDOG_TIME>0
	btst	USB_FLAGS, #UF_BUSY
	bra	z, 1f
	btst	U1CON, #TOKBUSY
	bra	z, 1f
	dec	uf_busy_watchdog
	bra	le, RESET_INSN
1:
.endif

	mov	TOKEN_ALLOWANCE, W0	; allow some more tokens
	add	TOKEN_STORE

	return
.popsection

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; USB error interrupt
6:
usb_error_isr:
	btst	U1IR, #UERRIF
	bra	z, 6f

	; nop		; FIXME target for debugger breakpoints
	; nop

	setm	U1EIR	; FIXME just attempt to clear the error

	; clear general error interrupt after specific in hope this
	; will help avoid immediate retriggering
	mov	#(1<<UERRIF), W0
	mov	W0, U1IR

	bclr	USB_FLAGS, #UF_BUSY	; token was destroyed by error
.ifdef PULSE_PIN14_ON_BUSY
	bclr	LATB, #5
.endif

	bra	after_transfer_complete

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; transfer complete:  return data to application, try sending more

6:
	btst	U1IR, #TRNIF
	bra	z, 6f

	mov	U1STAT, W1	; read U1STAT before clearing intr. flag
	mov	#(1<<TRNIF), W0
	mov	W0, U1IR

	bclr	USB_FLAGS, #UF_BUSY	; this token is done
.ifdef PULSE_PIN14_ON_BUSY
	bclr	LATB, #5
.endif

	mov	#bdt_rx, W3	; find BDT entry
	btsc	W1, #DIR
	mov	#bdt_tx, W3

	btst	[W3], #15	; check that we own the entry
	bra	nz, 6f		; abort if not (should this be worse error?)

	add	W3, #soft_bdt_offset, W0	; look at BDT shadow
	mov	[W0++], W1	; get IRP
	mov	[W0++], W2	; get endpoint

	mov	[W2+4], W0	; check that endpoint matches expectation
	mov	U1TOK, W5
	xor	W5, W0, W0
	and	W0, #0xF, W0
	bra	nz, 6f		; drop packet if it doesn't

	mov	[W3], W5	; look at incoming PID
	lsr	W5, #10, W5
	and	#0xF, W5

	; at this point W5 is incoming PID, W1 points to start of relevant
	; IRP, W2 points to link field of endpoint data structure, W3 points
	; to first (flags) field of BDT entry

	cp	W5, #PID_ACK
	bra	z, 2f
	cp	W5, #PID_DATA0
	bra	z, 2f
	cp	W5, #PID_DATA1
	bra	nz, 1f
2:
	; ACK, DATA0, or DATA1

	btg	[++W2], #EPF_DATA1	; toggle DTS bit for endpoint
	; W2 now points at flags field of endpoint

	mov	[W1+6], W0	; update byte count
	mov	[W3], W4
	and	#0x1FF, W4	; W4 is now packet size
	add	W0, W4, W5	; W5 is now buffer fill point
	mov	W5, [W1+6]

	clr	W3		; reset NAK count
	mov	W3, [W2+8]

	mov	[W2+6], W3	; get max length into W3

	; IF this is a CTRL transaction
	btst	[W1], #IRPF_CTRL
	bra	z, 2f

	;     AND if we've sent the ACK, then return IRP to foreground
	btst	[W1], #IRPF_ACK
	bra	nz, return_irp_to_foreground

	;     OTHERWISE, if buffer is full, then we should send the ACK
	mov	[W1+2], W0	; get buffer size
	cpslt	W5, W0		; compare with fill point
	bset	[W1], #IRPF_ACK		; set the ACK bit if full

	;     if fill point now 8 bytes, end of SETUP, don't check for short
	cp	W5, #8
	bra	eq, finished_incoming_packet

	;     if short packet, then too we should send ACK
	cpseq	W4, W3		; compare packet size with max length
	bset	[W1], #IRPF_ACK		; set the ACK bit if not max length

	;     no ACK yet, buffer not full:  need more packets
	bra	finished_incoming_packet	; go for more packets

2:
	; ELSE it's not a CTRL transaction
	;     AND if it's a short packet, then return to foreground
	cp	W4, W3
	bra	ltu, return_irp_to_foreground

	;     OTHERWISE, if buffer is not full, then go for more packets
	mov	[W1+2], W0	; get buffer size
	cp	W5, W0		; compare with fill point
	bra	ltu, finished_incoming_packet	; go for more packets

	;     max packet, buffer full:  FALL THROUGH, return to foreground
	; END IF

return_irp_to_foreground:
	; note at this point W1 should point to flags field of IRP

	mov	#0, W0			; disconnect endpoint from IRP
	mov	W0, [W2+4]
	bclr	[W1], #IRPF_UOWN	; return IRP to foreground
	bra	finished_incoming_packet

1:
	cp	W5, #PID_NAK
	bra	nz, 1f

	; NAK from several cases of things we might have sent

	btst	[++W2], #EPF_INFINITE_NAK	; do we care about NAKs?
	bra	nz, finished_incoming_packet

	add	W2, #8, W0	; bump the NAK counter
	inc	[W0], [W0]

	btst	[W1], #IRPF_INTR	; if INTR IN, this is success
	bra	z, 2f
	btst	[W1], #IRPF_WRITE
	bra	z, return_irp_to_foreground
2:

	; in other cases, NAK represents a failure but may not be a big one

	mov	[W0], W5	; load current NAK count

	mov	#3, W0		; number of NAKs to allow for INTR
	btst	[W1], #IRPF_INTR
	bra	nz, 2f
	mov	#200, W0	; number of NAKs to allow for CTRL
	btst	[W1], #IRPF_CTRL
	bra	nz, 2f
	mov	#20000, W0	; number of NAKs to allow for BULK
2:

	cp	W5, W0		; check for too many NAKs
	bra	ltu, finished_incoming_packet

	mov	#ERR_TOO_MANY_NAKS, W0	; return error to foreground
	mov	W0, [W2+10]
	bset	[W1], #IRPF_ERROR
	bra	return_irp_to_foreground

1:
	; STALL and hardware-defined PID values

	ior	W0, #ERR_PID_MASK, W0	; error code is PID+mask
	mov	W0, [W2+12]

	bset	[++W2], #EPF_STALLED	; stall and return error
	bset	[W1], #IRPF_ERROR
	bclr	[W1], #IRPF_UOWN

	; bra	finished_incoming_packet
	; FALL THROUGH

finished_incoming_packet:
	; Now try sending a new token.
	mov	current_endpoint, W2

send_next_in_isr:
	rcall	send_next_token

after_transfer_complete:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

6:

.ifdef PULSE_PIN14_ON_SOF
	bclr	LATB, #5	; test point goes low at end of interrupt
.endif

	; clean up and return - global labels provided for other ISRs to
	; return and restore registers, if they care more about saving
	; instructions than the time for the jump
;	pop	RCOUNT
.global RETFIE_INSN, RETFIE_W0, RETFIE_W0_1, RETFIE_W0_2
.global RETFIE_W0_3, RETFIE_W0_4, RETFIE_W0_5
RETFIE_W0_5:
	pop	W5
RETFIE_W0_4:
	pop	W4
RETFIE_W0_3:
	pop	W3
RETFIE_W0_2:
	pop	W2
RETFIE_W0_1:
	pop	W1
RETFIE_W0:
	pop	W0
RETFIE_INSN:
	retfie

.end
