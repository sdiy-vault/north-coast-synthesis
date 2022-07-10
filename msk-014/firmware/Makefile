#
# $Id: Makefile 9772 2022-01-19 04:17:12Z mskala $
#
# Makefile for MSK 014 firmware
# Copyright (C) 2022  Matthew Skala
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Matthew Skala
# https://northcoastsynthesis.com/
# mskala@northcoastsynthesis.com
#

CPU=24FJ64GB002
DEPDIR=deps

XC16DIR=/usr/local/opt/microchip/xc16/v1.60
AS=$(XC16DIR)/bin/xc16-as
BIN2HEX=$(XC16DIR)/bin/xc16-bin2hex
LD=$(XC16DIR)/bin/xc16-ld
NM=$(XC16DIR)/bin/xc16-nm
OBJDUMP=$(XC16DIR)/bin/xc16-objdump

ASOPTS=--listing-lhs-width2=24 --listing-cont-lines=1000

PERL=perl

RNDPAGE_LOW=0x0C
RNDPAGE_HIGH=0xA0

all: \
  $(DEPDIR)/.dirstamp firmware.frm
#  listing.pdf

debug: all

clean:
	rm -f *.o
	rm -f *.lst
	rm -f *.elf
	rm -f *.frm
	rm -f *.hex

SRCS= \
  calibration.s firmware.s image.s ledblink.s loader.s midi.s mouse.s \
  qwerty.s tests.s usb.s usbmass.s usbmidi.s utils.s

$(DEPDIR)/.dirstamp:
	mkdir -p $(DEPDIR)
	touch $(DEPDIR)/.dirstamp

%.o : %.s
	$(AS) -p $(CPU) --MD $(DEPDIR)/$*.Td $(ASOPTS) \
	  -aimlh=$*.lst -g -o $@ $<
	mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@

loader-lo.o: loader.s
	$(AS) -p $(CPU) --MD $(DEPDIR)/loader-lo.Td $(ASOPTS) \
	  -aimlh=loader-lo.lst -g -o $@ $<
	mv -f $(DEPDIR)/loader-lo.Td $(DEPDIR)/loader-lo.d && touch $@

loader-hi.o: loader.s loader-addr.inc mkloaddr
	$(AS) -p $(CPU) --MD $(DEPDIR)/loader-hi.Td $(ASOPTS) \
	  -aimlh=loader-hi.lst --defsym loader_high_copy=1 -g -o $@ $<
	mv -f $(DEPDIR)/loader-hi.Td $(DEPDIR)/loader-hi.d && touch $@

loader-addr.inc: loader-lo.o mkloaddr
	$(NM) loader-lo.o | $(PERL) mkloaddr > loader-addr.inc

firmware.elf: \
  calibration.o firmware.o ledblink.o loader-lo.o loader-hi.o midi.o \
  mouse.o qwerty.o tests.o usb.o usbmass.o usbmidi.o utils.o \
  p$(CPU).gld
	$(LD) \
	  --isr -p $(CPU) --stack=16 --check-sections --no-data-init \
	  --script=./p$(CPU).gld -Map=firmware.map --report-mem \
	  -o $@ $(filter %.o,$^)

%.hex : %.elf
	$(BIN2HEX) $<

firmware.hex: firmware.elf

firmware.bin fw-pages.inc: firmware.elf dmp2bin
	$(OBJDUMP) -shw $< \
	  | $(PERL) dmp2bin --pages fw-pages.inc > firmware.bin

%.syms : %.elf
	$(NM) $< > $@

%.syms : %.o
	$(NM) $< > $@

firmware.syms: firmware.elf

firmware.frm: image.s dmp2bin mkimagesyms \
  firmware.syms firmware.bin ./fw-pages.inc
	cat /dev/null > firmware.frm
	echo > image-syms.inc
	echo '.ascii "'`whoami ; hostname ; date`'"' > image-id.inc
	$(AS) -p $(CPU) --MD $(DEPDIR)/image.Td $(ASOPTS) \
	  -aimlh=image.lst -g -o image.o image.s
	mv -f $(DEPDIR)/image.Td $(DEPDIR)/image.d && touch image.o
	$(NM) image.o > image.syms
	$(OBJDUMP) -shw image.o | $(PERL) dmp2bin --flag MEMORY --mobies \
	  > firmware.frm
	while $(PERL) mkimagesyms firmware.frm image-syms.inc \
	    firmware.syms image.syms ; do \
	  $(AS) -p $(CPU) --MD $(DEPDIR)/image.Td $(ASOPTS) \
	    -aimlh=image.lst -g -o image.o image.s ; \
	  mv -f $(DEPDIR)/image.Td $(DEPDIR)/image.d && touch image.o ; \
	  $(NM) image.o > image.syms ; \
	  $(OBJDUMP) -shw image.o | $(PERL) dmp2bin --flag MEMORY --mobies \
	    > firmware.frm ; \
	  sha1sum image-syms.inc ; \
	done
	cp firmware.frm simdrive.bin

calibration.o: rndpage.inc

firmware.o: notetbl.inc

usbmass.o: simdrive.inc

notetbl.inc: mknotetbl
	$(PERL) ./mknotetbl > notetbl.inc

rndpage.inc: Makefile firmware.s
	$(PERL) \
	  -e '$$lo=$(RNDPAGE_LOW)&~3; $$hi=$(RNDPAGE_HIGH)&~3;' \
	  -e '$$x=($$lo+int(rand(1)*($$hi-$$lo)/4)*4)&~3;' \
	  -e 'printf ".equ __rndpage, 0x%02X\n",$$x;' > rndpage.inc

listing.ps: fmtlisting firmware.frm
	fmtlisting *.lst > listing.ps

listing.pdf: listing.ps
	ps2pdf listing.ps

$(DEPDIR)/%.d: ;
.PRECIOUS: $(DEPDIR)/%.d

include $(wildcard $(patsubst %,$(DEPDIR)/%.d,$(basename $(SRCS))))
include $(DEPDIR)/loader-hi.d $(DEPDIR)/loader-lo.d
