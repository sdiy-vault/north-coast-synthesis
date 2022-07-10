# $Id: Makefile 10137 2022-06-04 20:51:54Z mskala $

#
# MSK 013 source package Makefile
# Copyright (C) 2020, 2022  Matthew Skala
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

all: msk-013.pdf

msk-013.pdf: $(wildcard docs/*.pdf) $(wildcard docs/*.tex) \
  $(wildcard docs/*.jpg) $(wildcard docs/*.m4) $(wildcard docs/*.png) \
  $(wildcard docs/*.eps) \
  docs/bomdata.tex docs/bomdata-1.tex docs/bomdata-2.tex
	$(MAKE) -C docs msk-013.pdf panel-art.png
	cp docs/msk-013.pdf .

docs/bomdata.tex: csv2tex complexvco.csv
	./csv2tex complexvco.csv > docs/bomdata.tex

docs/bomdata-1.tex: csv2tex complexvco-1.csv
	./csv2tex complexvco-1.csv > docs/bomdata-1.tex

docs/bomdata-2.tex: csv2tex complexvco-2.csv
	./csv2tex complexvco-2.csv > docs/bomdata-2.tex

msk-013.zip: msk-013.pdf voct/voct-0.1.tar.gz
	cp voct/voct-0.1.tar.gz .
	rm -f msk-013.zip
	zip -r msk-013.zip \
	  msk-013.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/ncmanual.cls \
	  docs/adjustment.tex docs/board[12].tex docs/bom.tex \
	  docs/circuit.tex docs/drawings.tex docs/general.tex \
	  docs/msk-013.tex docs/panel-*.tex docs/patches.tex \
	  docs/warnings.tex \
	  docs/*.dxf docs/*.gp docs/*.jpg docs/*.m4 \
	  docs/botass.pdf docs/exploded.pdf docs/panel-mechanical.pdf \
	  docs/schematic.pdf docs/topass.pdf \
	  docs/bk[3-9].png docs/mp-patch?.png \
	  docs/current-ref.eps docs/expo-con.eps docs/pulse-shaper.eps \
	  docs/saw-shaper.eps docs/sh-*.eps docs/tri-core.eps \
	  layout.kicad_wks complexvco.kicad_pro complexvco.kicad_sch \
	  complexvco.kicad_prl complexvco.kicad_pcb \
	  voct-0.1.tar.gz

voct/voct: voct/voct.c
	$(MAKE) -C voct voct

voct/voct-0.1.tar.gz: voct/voct
	$(MAKE) -C voct dist
