# $Id: Makefile 10138 2022-06-04 23:46:50Z mskala $

#
# MSK 014 source package Makefile
# Copyright (C) 2021, 2022  Matthew Skala
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

all: msk-014-user.pdf msk-014-prog.pdf

msk-014-user.pdf msk-014-prog &: \
  $(wildcard docs/*.pdf) $(wildcard docs/*.tex) \
  $(wildcard docs/*.jpg) $(wildcard docs/*.m4) $(wildcard docs/*.png) \
  $(wildcard docs/*.eps) \
  docs/bomdata.tex docs/bomdata-1.tex docs/bomdata-2.tex
	$(MAKE) -C docs msk-014-user.pdf msk-014-prog.pdf panel-art.png
	cp docs/msk-014-user.pdf docs/msk-014-prog.pdf .

docs/bomdata.tex: csv2tex usb-host.csv
	./csv2tex usb-host.csv > docs/bomdata.tex

docs/bomdata-1.tex: csv2tex usb-host-1.csv
	./csv2tex usb-host-1.csv > docs/bomdata-1.tex

docs/bomdata-2.tex: csv2tex usb-host-2.csv
	./csv2tex usb-host-2.csv > docs/bomdata-2.tex

msk-014.zip: msk-014-user.pdf msk-014-prog.pdf
	rm -f msk-014.zip
	zip -r msk-014.zip \
	  msk-014-user.pdf msk-014-prog.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/ncmanual.cls \
	  docs/board[12].tex docs/bom.tex docs/buildtools.tex \
	  docs/calibration.tex docs/calibrations.tex \
	  docs/circuit.tex docs/drawings.tex docs/firmwares.tex \
	  docs/general.tex docs/glossary.tex \
	  docs/introduction.tex docs/jackview.tex docs/keyboard.tex \
	  docs/ledblinks.tex docs/loaders.tex docs/midi.tex docs/midis.tex \
	  docs/mouse.tex docs/mouses.tex \
	  docs/msk-014-user.tex docs/msk-014-prog.tex docs/nonusb.tex \
	  docs/offchip.tex docs/onchip.tex docs/panel-*.tex docs/patches.tex \
	  docs/progtips.tex docs/qwerty.tex docs/qwertys.tex \
	  docs/testss.tex docs/timers.tex docs/usbmasss.tex docs/usbmidis.tex \
	  docs/usbs.tex docs/utilss.tex docs/warnings.tex \
	  docs/failure.ly docs/success.ly \
	  docs/*.dxf docs/*.jpg docs/*.png \
	  docs/botass.pdf docs/exploded.pdf docs/opamp[123].eps \
	  docs/panel-mechanical.pdf docs/schematic.pdf docs/topass.pdf \
	  firmware/Makefile firmware/*.s firmware/*.inc \
	  firmware/dmp2bin firmware/fmtlisting firmware/mkimagesyms \
	  firmware/mkloaddr firmware/mknotetbl firmware/mksimdrives \
	  firmware/p24FJ64GB002.gld firmware/simdrive-images.zip \
	  layout.kicad_wks usb-host.kicad_pro usb-host.kicad_prl \
	  usb-host.kicad_sch usb-host.kicad_pcb
