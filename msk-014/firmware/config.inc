; Configuration defines for MSK 014 firmware
; $Id: config.inc 9764 2022-01-15 22:19:11Z mskala $
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

; clock options

; use Fast RC oscillator; no USB but works on eval board with no external
; .equ FRC_OSC, 1

; turn off the watchdog timer, for in-circuit debugging
; .equ NO_WDT, 1

; number of instruction times to pause when checking for attach/detach/speed
; with 16MHz instruction clock, units are 62.5ns
.equ USB_BUS_SETTLING_TIME, 24	; 1.5us

; reset if UF_BUSY remains true more than this many milliseconds, 0 to
; disable
.equ UF_BUSY_WATCHDOG_TIME, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; hardware simulations - for testing in Microchip's simulator

; fake ADC voltages for testing calibration
; .equ SIMULATE_CALIBRATION_ADC, 1

; fake comparator timestamps for testing calibration
; .equ SIMULATE_CALIBRATION_OSC, 1

; fake SRAM reads with program memory for testing loader
; .equ SIMULATE_SRAM, 1

; fake a USB mass storage device for testing filesystem code
; value is 1..6 for different sample filesystem contents
; .equ SIMULATE_USB_MASS, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; miscellaneous debugging aids

; fill RAM with 0xDEAD on startup to make it easier to see what's touched
; .equ FILL_RAM_DEAD, 1

; LEDs go red and green on USB attach and detach interrupts
; .equ LEDS_ON_USB_ATTACHED, 1

; pulse pin 14 (RB7) according to UF_BUSY flag
; .equ PULSE_PIN14_ON_BUSY, 1

; pulse pin 14 (RB7) on USB SOF interrupt
; .equ PULSE_PIN14_ON_SOF, 1

; do the calibration threads one after another instead of simultaneously
; .equ SEQUENTIAL_CALIBRATION, 1

; assemble stub handlers to catch "traps" for debugging
; bitmask, 2 = oscillator failure, 4 = address error
; 8 = stack error, 16 = math error
; .equ TRAP_HANDLERS, 30

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; module tests - replace main loop with something we can probe in hardware

; don't execute tests on startup (must define this for production firmware!)
.equ SKIP_TESTS, 1

; run the calibration as a test, on startup
; .equ TEST_CALIBRATION, 1

; test hardware CRC32 calculation
; .equ TEST_CRC32, 1

; test/demo LED blinker driver
; .equ TEST_LED_BLINKER, 1

; test MIDI stream decoding and the backend
; .equ TEST_MIDI_STREAM, 1

; test PRNG
; .equ TEST_PRNG, 1

; test SPI transactions
; .equ TEST_SPI, 1

; activate USB eye pattern generator
; .equ TEST_USB_EYE_PATTERN, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Allowable difference between highest and lowest of 16 measurements during
; input calibration
.equ INPUT_CAL_FUZZ, 6

; Allowable difference in period counts between successive measurements
; during output calibration
.equ OUTPUT_CAL_FUZZ, 20

; Amount of hysteresis (measured in units of 1/256 of a semitone for HALF
; the hysteresis band, hence default is a band of 62.5 cents) in
; quantization modes
.equ QUANT_HYSTERESIS, 0x50

; Rate at which Shift keys on QWERTY keyboard affect the pitch bend amount. 
; Units are MIDI pitch bend units (entire range of pitch bend is -8K to +8K
; MIDI pitch bend units and covers -2 to +2 semitones by default) per
; millisecond, hence each rate unit is 24.41 cents per second with the
; default bend range.
.equ QWERTY_PBEND_RATE, 24

; Rate at which pitch bend returns to zero in QWERTY driver with no or both
; Shift keys pressed, same units as above
.equ QWERTY_PBEND_RETURN, 18
