.psize 44,144
.title "Firmware for MSK 014 Gracious Host"
.sbttl "$Id: firmware.s 9758 2022-01-08 17:01:16Z mskala $"
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Global include file"

; this is included in many places, but only shown in the listing here in
; firmware.s, because we want to list it somewhere.

.equ LIST_GLOBAL_INC, 1
.include "global.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Config fuses and debugging RAM reservation"

; Deep Sleep WDT disabled; we won't use Deep Sleep
.section __CONFIG4.sec, code
.global __CONFIG4
__CONFIG4: .pword DSWDTEN_OFF

; use secondary oscillator pins for I/O
; disable segment protection
; do protect the last page and config words
.section __CONFIG3.sec, code
.global __CONFIG3
__CONFIG3: .pword SOSCSEL_IO & WPDIS_WPDIS & WPCFG_WPCFGEN

.ifdef FRC_OSC

  ; FRC oscillator (for testing on dev. board that has no external)
  ; note we can't actually do USB in this mode
  ; allow unlocking the peripheral config (you can brick board if you wanna)
  ; use the oscillator output pin as a GPIO pin
  ; don't allow clock switching
  ; use FRCPLL clock:  built-in clock with PLL multiplier
  ; automatically start the 96MHz PLL on boot
  ; input clock is 8MHz, divide by 2 to get 4MHz for the PLL
  ; disable two-speed startup (silicon erratum:  it doesn't work)
  .section __CONFIG2.sec, code
  .global __CONFIG2
  __CONFIG2:
  .pword POSCMOD_NONE & IOL1WAY_OFF & OSCIOFNC_ON & FCKSM_CSDCMD & FNOSC_FRCPLL & PLL96MHZ_ON & PLLDIV_DIV2 & IESO_OFF

.else

  ; EC oscillator mode (external input)
  ; allow unlocking the peripheral config (you can brick board if you wanna)
  ; use the oscillator output pin as a GPIO pin
  ; don't allow clock switching
  ; use ECPLL clock:  external input with PLL multiplier
  ; automatically start the 96MHz PLL on boot
  ; input clock is 4MHz, divide by 1 to get 4MHz for the PLL
  ; disable two-speed startup (silicon erratum:  it doesn't work)
  .section __CONFIG2.sec, code
  .global __CONFIG2
  __CONFIG2:
  .pword POSCMOD_EC & IOL1WAY_OFF & OSCIOFNC_ON & FCKSM_CSDCMD & FNOSC_PRIPLL & PLL96MHZ_ON & PLLDIV_NODIV & IESO_OFF

.endif

.ifdef NO_WDT

  ; debug configuration without WDT:
  ; watchdog timer disabled
  ; emulator functions on PGEC1/PGED1 (silicon erratum:  using PGEC3/PGED3
  ;    conflicts with using the ADCs)
  ; program memory write allowed
  ; code protection disabled
  ; JTAG port disabled
  .section __CONFIG1.sec, code
  .global __CONFIG1
  __CONFIG1:
  .pword FWDTEN_OFF & ICS_PGx1 & GWRP_OFF & GCP_OFF & JTAGEN_OFF

.else

  ; production configuration:
  ; watchdog postscaler 1:256
  ; watchdog prescalar 1:128
  ; this means a 1.024s nominal watchdog period
  ; windowed watchdog mode off
  ; emulator functions on PGEC1/PGED1 (silicon erratum:  using PGEC3/PGED3
  ;    conflicts with using the ADCs)
  ; program memory write allowed
  ; code protection disabled
  ; JTAG port disabled
  .section __CONFIG1.sec, code
  .global __CONFIG1
  __CONFIG1:
  .pword WDTPS_PS256 & FWPSA_PR128 & WINDIS_OFF & FWDTEN_ON & ICS_PGx1 & GWRP_OFF & GCP_OFF & JTAGEN_OFF

.endif

; section for the common data area, because we have to put it somewhere

.global _common
.section common_data, bss, near
_common:	.skip __common_size

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Last page of program memory"

; last page of Flash memory contains the config bits; it cannot be safely
; erased under program control, only by ICSP.  this makes it a good place
; for a copyright notice and version number.

.pushsection last_page,code,address(0xA800)

; loader looks for this here, in this format, with Program Space Visibility
.global HARDWARE_ID
HARDWARE_ID:
	.ascii "MSK 014",<1>

; since we can afford the space here and shouldn't put anything in this page
; that might change, let's use it for some constant data that is more or
; less timeless and might be useful to firmware:  a table of period values
; for playing MIDI notes.  These are values suitable for use with "output
; compare" PWM when the dedicated counters are driven by 1:8 prescaling from
; the system clock, that is, rounded values of the formula (2MHz/f)-1.  Same
; frequency scheme used for playing notes in the loader.  Indices run 0 to
; 128 for easy indexing from MIDI notes; 128 invalid but useful as a
; sentinel.  Values too big to fit in 16 bits are replaced by 0 and will
; probably cause output compare to go to DC.
.global NOTE_TBL
NOTE_TBL:
.include "notetbl.inc"

; now do a reset, so we won't execute the packed ASCII text
	reset

colophon:
	.pascii "MSK 014 firmware\n"
	.pascii "$Id: firmware.s 9758 2022-01-08 17:01:16Z mskala $\n"
	.pascii "Copyright (C) 2022 Matthew Skala\n"
	.pbyte  0

; consume rest of page to prevent the linker putting anything else there
; leave 8 bytes for config, 2 for the last word of program memory, which the
; linker will not allow us to touch
	.pfillvalue 0xFF
	.porg 0x0400-10
.popsection

; set a symbol telling the linker that we need to reserve RAM for in-circuit
; debugging

.global __ICD2RAM
.equ __ICD2RAM,1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Power-on reset"

.section .text

.global __reset
__reset:
	; stack init
	mov     #__SP_init, W15
	mov     #__SPLIM_init, W0
	mov     W0, _SPLIM

	clr	TBLPAG	; only zero TBLPAG makes sense on this device

.ifdef FILL_RAM_DEAD
	; fill RAM with marker data
	mov	#0xDEAD, W0
	mov	#0x0850, W1
	repeat	#4055
	mov	W0, [W1++]
.endif

	mov	#handle(RESET_INSN), W1	; default handler resets
	rcall	TRY

	rcall	STANDARD_IO_CONFIG	; ADC, GPIO, other peripherals

	; Peripheral Pin Select mapping - already unlocked by reset default

	; PPS map SPI1 data out to RP2 (pin 6)
	; PPS map SPI1 clock out to RP3 (pin 7)
	mov	#0x0807, W0
	mov	W0, RPOR1

	; PPS map SPI1 data in to RP4 (pin 11)
	mov	#0x1F04, W0
	mov	W0, RPINR20

	rcall	CALIBRATION_TO_RAM	; load calibration data from flash

.ifndef SKIP_TESTS
	rcall	RUN_TESTS
.endif
.ifdef SIMULATE_USB_MASS
	bra	_USB_MASS_ENTRY
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Non-USB behaviour"

non_usb_init:
	rcall	USB_INIT	; listen for device attach
	rcall	PPS_MAP_OC_DOUT	; send output compare to DOUT jacks
	bset	IEC1, #CMIE	; enable comparator interrupt
	clr	LATB		; port B to all zeros (makes LEDs red)

	mov	#0x2400, W8	; envelope value
	clr	W9		; flag:  completed attack

non_usb_loop:
	bclr	SOFT_INT_FLAGS, #SI_ADC1
	pwrsav	#1	; wait for an interrupt

	rcall	USB_TEST_ATTACHED
	bra	nz, non_usb_done

	btst	CMSTAT, #C1OUT	; check input 2 for gate
	bra	nz, gate_high

	; gate is low

	bset	TRISB, #7	; LEDs off
	bset	TRISB, #9

	clr	OC1R	; turn off unquantized oscillator
	clr	OC1RS

	; update the envelope, if a 618us ADC tick has occurred
	btst	SOFT_INT_FLAGS, #SI_ADC1
	bra	z, non_usb_loop

	clr	W9	; back to attack state
	sub	#86, W8	; release rate 86ct/618us (55.2ms from sustain)
	mov	#0x2400, W0
	cp	W8, W0
	bra	gt, tune_oscillators
	mov	#0x2400, W8
	bra	tune_oscillators

gate_high:
	; gate high, play notes

	bclr	TRISB, #7	; LEDs on
	bclr	TRISB, #9

	; update the envelope, if a 618us ADC tick has occurred
	btst	SOFT_INT_FLAGS, #SI_ADC1
	bra	z, non_usb_loop

	cp0	W9		; are we still in attack?
	bra	nz, 1f

	add	#341, W8	; attack rate 341ct/618us, (27.8ms to peak)
	mov	#0x6000, W0
	cp	W8, W0		; check for end of attack
	bra	ltu, tune_oscillators

	setm	W9		; attack ended, set flag
	mov	#0x6000, W8	; force peak to be exact
	bra	tune_oscillators

1:
	mov	#0x4200, W0	; stop decay at sustain level of 0x4200
	cp	W8, W0
	bra	leu, tune_oscillators

	sub	#60, W8		; decay rate 60ct/618us, (79.1ms to sustain)

tune_oscillators:
	rcall	ADC1_TO_NOTENUM	; figure out input note
	rcall	CALC_OSC_TUNING	; figure out how to tune OC1 for this note

	btst	CMSTAT, #C1OUT	; check input 2 for gate
	bra	z, 1f		; don't play unquantized note if gate low
	lsr	W0, W1		; set output compare 1 to play note
	mov	W1, OC1R
	mov	W0, OC1RS
1:

	add	#0x80, W7	; round off note value
	lsr	W7, #8, W7

	sl	W7, #8, W0	; interpolate rounded value and send to DAC
	rcall	NOTENUM_TO_DAC1
	
	sl	W7, W7		; look up in table
	add	W6, W7, W1
	tblrdl	[W1], W0

	lsr	W0, W1		; set output compare 2 to quantized note
	mov	W1, OC2R
	mov	W0, OC2RS

	mov	W8, W0		; send envelope value to DAC2
	rcall	NOTENUM_TO_DAC2

	bra	non_usb_loop

non_usb_done:
	bclr	TRISB, #7	; LEDs on, green
	bclr	TRISB, #9
	bset	LATB, #7
	bset	LATB, #9

	clr	OC1R		; turn off oscillators
	clr	OC1RS
	clr	OC2R
	clr	OC2RS

	mov	#handle(catch_usb_session), W1
	rcall	TRY
	rcall	USB_HANDLE_SESSION	; commence primary ignition
	rcall	TRIED
	bra	1f

catch_usb_session:
	rcall	LEDBLINK_INIT	; very fast back-forth red LEDs
	clr	LEDBLINK_RB7
	clr	LEDBLINK_RB9
	mov	#0xAAAA, W0
	mov	W0, LEDBLINK_TRIS7
	mov	#0x5555, W0
	mov	W0, LEDBLINK_TRIS9

2:
	bset	U1IE, #DETACHIE	; enable device detach interrupt
	pwrsav	#1		; wait until proper disconnect
	rcall	USB_TEST_ATTACHED
	bra	nz, 2b

1:
	rcall	USB_DONE	; this turns off SOF/keep-alive generation
	rcall	LEDBLINK_DONE	; even if we didn't init, b/c driver might've
	bra	non_usb_init

; Calculate the period value for an output compare timer to play a note.
; Input in W0, on scale where MIDI note number is on high byte and fraction
; in low byte.  This gets copied to W7.  Output in W0 is value for OCxRS.
; Also leaves the note table address in W6.  Trashes W1, W2, W3.
; Pulled out into a subroutine so we can reuse it in the MIDI driver.
.global CALC_OSC_TUNING
CALC_OSC_TUNING:
	mov	W0, W7		; save the note number

	lsr	W0, #8, W0	; get an index into the note period table
	sl	W0, W0

	; look up this, and the next, period in the table
	mov	#tbloffset(NOTE_TBL), W6
	add	W0, W6, W1
	tblrdl	[W1++], W2
	tblrdl	[W1], W3

	; interpolate fractional note number to period
	mov.b	W7, W0		; W0 high is zero b/c input note =<128
	sub	W2, W3, W1
	mul.uu	W0, W1, W0	; multiply period difference by fraction
	mov.b	W1, W0		; poor man's divide W1:W0 by 256 --> W0
	swap	W0
	sub	W2, W0, W0	; subtract offset from table value

	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "Basic I/O subroutines"

; unlock Peripheral Pin Select configuration
; trashes W0, W3, W4
.global UNLOCK_PPS
UNLOCK_PPS:
	mov	#OSCCON, W0
	mov	#0x46, W3
	mov	#0x57, W4
	mov.b	W3, [W0]
	mov.b	W4, [W0]
	bclr	OSCCON, #IOLOCK
	return

; lock Peripheral Pin Select configuration
; trashes W0, W3, W4
.global LOCK_PPS
LOCK_PPS:
	mov	#OSCCON, W0
	mov	#0x46, W3
	mov	#0x57, W4
	mov.b	W3, [W0]
	mov.b	W4, [W0]
	bset	OSCCON, #IOLOCK
	return

; this is pulled into a subroutine so we can call it e.g. in calibration
.global STANDARD_IO_CONFIG
STANDARD_IO_CONFIG:
	clr	SOFT_INT_FLAGS	; clear VBUS_TRIP in particular

	; GPIO ports

	clr	LATB		; port B outputs default low
	clr	ODCB		; no open-drain on port B
	mov	#0xBEDF, W0	; LEDs off, digital outs and test point low
	mov	W0, TRISB

	setm	LATA		; port A output bits default high
	clr	ODCA		; no open-drain on port A
	mov	#0xFFE5, W0	; RA1, RA3, RA4 are GPIO outputs
	mov	W0, TRISA

	; interrupt priorities
	; ADC and output compare left at default priority 4
	bset	IPC4, #9	; comparator priority 6
	mov	#0x2444, W0	; Timer 1 and 2 priority 2
	mov	W0, IPC0
	mov	W0, IPC1
	bset	IPC21, #8	; USB priority 5

	; Timers 1 and 2:  1:256 prescale (62.5kHz input), stopped
	mov	#0x0030, W0
	mov	W0, T1CON
	mov	W0, T2CON

	; Timer 1 max period (1.048s) and 1/32nd of it after overflow
	setm	PR1
	mov	#0x800, W0
	mov	W0, TMR1

	; Timer 2 period 4096 counts (65.536 ms), stopped at zero
	mov	#0x0FFF, W0
	mov	W0, PR2
	clr	TMR2

	; start Timers 1 and 2
	disi	#2
	bset	T1CON, #TON
	bset	T2CON, #TON

	; Timer 3 - count at 2MHz, reset at 4.854kHz (= 3 * golden ratio
	; * 1kHz) to provide sync for ADC and prescale for output compares.
	; Golden ratio is to avoid a beat frequency pattern against the 1kHz
	; USB full-speed event.  We use 1:8 prescale and a count of 412
	; instead of 1:1 and a count of 3296, so that the prescale output
	; will be useful for output compares as well.
	mov	#0x0010, W0	; set T3 prescale to 1:8, 2MHz count rate
	mov	W0, T3CON
	mov	#411, W0	; period 206 us
	mov	W0, PR3
	bset	T3CON, #TON	; start counting

	; disable Timers 4 and 5
	clr	T4CON
	clr	T5CON

	; configure all output compares for edge-aligned PWM, 0% duty cycle
	mov	#OC1CON1, W1	; start of output compare register area
1:
	mov	#0x0406, W0	; use T3 prescaler, edge-aligned PWM
	mov	W0, [W1++]	; OCxCON1
	mov	#0x001F, W0	; sync this OC module from itself
	mov	W0, [W1++]	; OCxCON2
	clr	[W1++]		; OCxRS
	clr	[W1++]		; OCxR
	inc2	W1, W1		; OCxTMR
	mov	#OC5TMR, W0	; loop over all five OC modules
	cp	W1, W0
	bra	leu, 1b

	; ADC
	mov	#0x44, W0	; convert on T3 compare, auto-start sample
	mov	W0, AD1CON1
	mov	#0x0408, W0	; full range, scan, int after 3 conversions
	mov	W0, AD1CON2
	mov	W0, AD1CON3	; auto-sample 4 cycles, conversion clock /9
	clr	AD1CHS		; select AN0 and internal reference in muxes
	mov	#0xF5FE, W0	; enable AN0, AN9, AN11, no references
	mov	W0, AD1PCFG
	com	W0, W0		; scan exactly the pins that are analog ins
	mov	W0, AD1CSSL
	clr	vbus_low_count	; need this sane before we start checking it
	bset	AD1CON1, #ADON	; start converting
	bset	IEC0, #AD1IE	; allow ADC interrupts (default priority 4)

	; comparator voltage reference

	; Silicon erratum for comparator voltage reference:  when VREF- is
	; set to any of the internal bandgap reference options, it is said
	; that some interrupts may be missed.  Not clear whether that
	; applies to configurations like ours in which we aren't actually
	; using VREF- as input to any comparator, and we have not observed
	; missed interrupts, but we have observed unrequested interrupts
	; (on falling edge when we only wanted rising edge), so for greater
	; caution, we are configuring VREF- to the external pin.  This is
	; pin 2, already used as analog input for DIN1, so it should be
	; reasonably safe to set this configuration.

	mov	#0x038F, W0	; 2.372V as seen at MPU pins
	mov	W0, CVRCON	; 1.62V nominal at input jack

	; comparators
	mov	#0x8051, W0	; look for rising edges, INC vs Vref+
	; input amps are inverting but so is comparator input selection
	; so it cancels; rising edge on comp output is rising on jack input
	mov	W0, CM1CON	; comparator 1 for input jack 2
	mov	W0, CM3CON	; comparator 3 for input jack 1
	; interrupts not enabled here, only later if we want them

	; Serial Peripheral Interface (SPI)

	; internal SPI clock
	; data output enable
	; byte communication
	; sample data in middle of output time
	; output changes on falling edge of clock
	; no ~SS1 pin (we use GPIOs for that)
	; clock is active high
	; master mode
	; 1:1 primary, 1:2 secondary prescalers (8MHz SPI clock)
	mov	#0x013B, W0
	mov	W0, SPI1CON1
	; disable framed mode, enable enhanced buffer mode
	mov	#0x1, W0
	mov	W0, SPI1CON2
	; enable the module
	bset	SPI1STAT, #SPIEN

	clr	SOFT_INT_FLAGS	; clear out the soft interrupts

	return

.global PPS_MAP_OC_DOUT
PPS_MAP_OC_DOUT:
	rcall	UNLOCK_PPS
	mov	#0x0013, W0	; PPS map output compare 2 to RP8
	mov	W0, RPOR4
	mov	#0x0012, W0	; PPS map output compare 1 to RP14
	mov	W0, RPOR7
	rcall	LOCK_PPS
	return

.global PPS_MAP_GPIO_DOUT
PPS_MAP_GPIO_DOUT:
	rcall	UNLOCK_PPS
	clr	RPOR4
	clr	RPOR7
	rcall	LOCK_PPS
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.eject
.sbttl "A/D conversion and USB short detection"

; SOFT_INT_FLAGS is actually shared with several other subsystems, but it
; has to be defined somewhere.  The other three are auto-updated at the
; 1.618kHz frequency of the ADC interrupt, which is a 1:3 division of the
; Timer 3 interrupt.

.global SOFT_INT_FLAGS, INPUT_ADC1, INPUT_ADC2, USB_VBUS_ADC
.pushsection .bss
SOFT_INT_FLAGS:	.skip 2
INPUT_ADC1:	.skip 2
USB_VBUS_ADC:	.skip 2
INPUT_ADC2:	.skip 2
vbus_low_count:	.skip 2
.popsection

.equ VBUS_TRIP, 558	; corresponds to 3.60V
.equ VBUS_RESET, 620	; corresponds to 4.00V
.equ VBUS_LOW_TIME, 162	; corresponds to 100ms
.equ VBUS_HIGH_TIME, 1618	; corresponds to 1s

.section .isr, code
.global __ADC1Interrupt
__ADC1Interrupt:
	push	W0
	bclr	IFS0, #AD1IF

	mov	ADC1BUF0, W0
	mov	W0, INPUT_ADC1
	mov	ADC1BUF1, W0
	mov	W0, USB_VBUS_ADC
	mov	ADC1BUF2, W0
	mov	W0, INPUT_ADC2

	mov	#VBUS_TRIP, W0	; check for too-low voltage
	cp	USB_VBUS_ADC
	bra	gt, 1f

	inc	vbus_low_count	; too low, see how long it's been low
	mov	#VBUS_LOW_TIME, W0
	cp	vbus_low_count
	bra	lt, 2f

	mov	W0, vbus_low_count
	bset	SOFT_INT_FLAGS, #SI_VBUS_TRIP

1:
	mov	#VBUS_RESET, W0	; check for high-enough voltage
	cp	USB_VBUS_ADC
	bra	le, 2f

	clr	vbus_low_count

2:
	bset	SOFT_INT_FLAGS, #SI_ADC1
	bset	SOFT_INT_FLAGS, #SI_ADC2

	bra	RETFIE_W0

.section .text

; Call this periodically to make sure VBUS hasn't dropped, indicating a
; short circuit on the USB power.  If it *has*, then we complain until it
; recovers, and reset.
.global CHECK_VBUS
CHECK_VBUS:
	btss	SOFT_INT_FLAGS, #SI_VBUS_TRIP
	return		; quick return if bus has not tripped

	; okay, we're in trouble.  Tear down I/O config and just complain.
	rcall	USB_DONE
	rcall	PPS_MAP_GPIO_DOUT
	clr	LATB

	; set up LED blinking with interrupted red, short green flashes
	rcall	LEDBLINK_INIT
	mov	#0x0840, W0
	mov	W0, LEDBLINK_RB7
	mov	#0x0003, W1
	mov	W1, LEDBLINK_TRIS7
	swap	W0
	mov	W0, LEDBLINK_RB9
	swap	W1
	mov	W1, LEDBLINK_TRIS9

2:
	clr	W2	; track how long it has been up
1:
	pwrsav	#1	; wait for a tick
	btst	SOFT_INT_FLAGS, #SI_ADC1
	bra	z, 1b
	bclr	SOFT_INT_FLAGS, #SI_ADC1

	mov	#VBUS_TRIP, W0	; check for too-low voltage
	cp	USB_VBUS_ADC
	bra	le, 2b		; keep waiting and reset count if so

	mov	#VBUS_RESET, W0	; check for high-enough voltage
	cp	USB_VBUS_ADC
	bra	le, 1b		; keep waiting but keep count if not reached

	inc	W2, W2		; see if it's been high long enough
	mov	#VBUS_HIGH_TIME, W0
	cp	W2, W0
	bra	lt, 1b

	reset

.end
