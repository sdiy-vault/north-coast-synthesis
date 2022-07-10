# $Id: Makefile 5832 2018-01-01 22:40:00Z mskala $

#
# MSK 008 source package Makefile
# Copyright (C) 2017, 2022  Matthew Skala
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

all: msk-008.pdf msk-008.zip

msk-008.pdf: docs/*.pdf docs/*.tex *.csv docs/*.jpg docs/*.m4 \
  docs/bomdata.tex docs/bomdata-1.tex docs/bomdata-2.tex
	$(MAKE) -C docs msk-008.pdf panel-art.pdf panel-mockup.pdf
	cp docs/msk-008.pdf .

docs/bomdata.tex: csv2tex octave-switch.csv
	./csv2tex octave-switch.csv > docs/bomdata.tex

docs/bomdata-1.tex: csv2tex octave-switch-1.csv
	./csv2tex octave-switch-1.csv > docs/bomdata-1.tex

docs/bomdata-2.tex: csv2tex octave-switch-2.csv
	./csv2tex octave-switch-2.csv > docs/bomdata-2.tex

msk-008.zip: msk-008.pdf Makefile
	rm -f msk-008.zip
	zip -r msk-008.zip \
	  msk-008.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/*.jpg docs/board1.tex docs/board2.tex \
	  docs/bom.tex docs/circuit.tex docs/comp-curr.m4 \
	  docs/comp-curr2.m4 docs/comparator.m4 docs/drawings.tex \
	  docs/exploded.dxf docs/general.tex \
	  docs/led-design.m4 docs/led-network.m4 docs/manual-switch.m4 \
	  docs/msk-008.tex docs/panel-art.tex docs/panel-master.tex \
	  docs/panel-mechanical.dxf docs/panel-mockup.tex docs/patch?.png \
	  docs/patches.tex docs/skeleton.m4 docs/testing.tex docs/vgen.eps \
	  docs/vreg.jpg docs/warnings.tex \
	  docs/ncmanual.cls \
	  layout.kicad_wks lednetwork.ecl \
	  octave-switch.kicad_pcb octave-switch.kicad_pro octave-switch.kicad_sch \
	  docs/schematic.pdf docs/topass.pdf docs/botass.pdf \
	  docs/panel-mechanical.pdf docs/exploded.pdf
