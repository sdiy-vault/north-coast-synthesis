# $Id: Makefile 10134 2022-06-04 14:32:50Z mskala $

#
# MSK 010 source package Makefile
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

all: msk-010.pdf msk-010.zip

msk-010.pdf: docs/*.pdf docs/*.tex \
  docs/bomdata.tex docs/bomdata-1.tex docs/bomdata-2a.tex \
  docs/bomdata-2b.tex docs/bomdata-2c.tex docs/*.jpg docs/*.m4
	$(MAKE) -C docs panel-mockup.pdf msk-010.pdf
	cp docs/msk-010.pdf .

docs/bomdata.tex: csv2tex manysine.csv
	./csv2tex manysine.csv > docs/bomdata.tex

docs/bomdata-1.tex: csv2tex manysine-1.csv
	./csv2tex manysine-1.csv > docs/bomdata-1.tex

docs/bomdata-2a.tex: csv2tex manysine-2a.csv
	./csv2tex manysine-2a.csv > docs/bomdata-2a.tex

docs/bomdata-2b.tex: csv2tex manysine-2b.csv
	./csv2tex manysine-2b.csv > docs/bomdata-2b.tex

docs/bomdata-2c.tex: csv2tex manysine-2c.csv
	./csv2tex manysine-2c.csv > docs/bomdata-2c.tex

msk-010.zip: msk-010.pdf
	rm -f msk-010.zip
	zip -r msk-010.zip \
	  msk-010.pdf COPYING Makefile \
	  csv2tex \
	  docs/*.jpg docs/Makefile docs/board1.tex docs/board2a.tex \
	  docs/board2b.tex docs/board2c.tex docs/bom.tex docs/circuit.tex \
	  docs/drawings.tex docs/fakevdiv.m4 docs/gain3.m4 docs/gain32.m4 \
	  docs/general.tex docs/msk-010.tex docs/oscillator.pdf \
	  docs/panel-010.iges docs/panel-art.tex docs/panel-master.tex \
	  docs/panel-mechanical.dxf docs/panel-mockup.tex \
	  docs/panel-print.png docs/patch?.png docs/patches.tex docs/rc2.eps \
	  docs/schematic.pdf docs/testing.tex docs/vdiv.m4 \
	  docs/warnings.tex docs/wienbridge.m4 docs/zeners.m4 \
	  docs/topass.pdf docs/botass.pdf docs/exploded.dxf \
	  docs/mechanical?.pdf docs/panel-mechanical.pdf docs/exploded.pdf \
	  docs/ncmanual.cls \
	  layout.kicad_wks manysine-1.csv manysine-2a.csv manysine-2b.csv \
	  manysine-2c.csv manysine.csv manysine.kicad_pcb manysine.kicad_pro \
	  manysine.kicad_sch
