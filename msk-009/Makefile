# $Id: Makefile 10098 2022-05-27 20:40:50Z mskala $

#
# MSK 009 source package Makefile
# Copyright (C) 2018, 2022  Matthew Skala
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

all: msk-009.pdf

msk-009.pdf: $(wildcard docs/*.pdf) $(wildcard docs/*.tex) \
  $(wildcard docs/*.jpg) $(wildcard docs/*.m4) $(wildcard docs/*.png) \
  $(wildcard docs/*.eps) \
  docs/bomdata.tex docs/bomdata-1.tex docs/bomdata-2.tex
	$(MAKE) -C docs msk-009.pdf panel-art.png
	cp docs/msk-009.pdf .

docs/bomdata.tex: csv2tex coiler.csv
	./csv2tex coiler.csv > docs/bomdata.tex

docs/bomdata-1.tex: csv2tex coiler-1.csv
	./csv2tex coiler-1.csv > docs/bomdata-1.tex

docs/bomdata-2.tex: csv2tex coiler-2.csv
	./csv2tex coiler-2.csv > docs/bomdata-2.tex

msk-009.zip: msk-009.pdf
	rm -f msk-009.zip
	zip -r msk-009.zip \
	  msk-009.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/ncmanual.cls \
	  docs/adjustment.tex docs/board[12].tex docs/bom.tex \
	  docs/circuit.tex docs/drawings.tex docs/general.tex \
	  docs/msk-009.tex docs/panel-*.tex docs/patches.tex \
	  docs/warnings.tex \
	  docs/*.dxf docs/*.gp docs/*.jpg docs/*.m4 \
	  docs/botass.pdf docs/exploded.pdf docs/expoconv.pdf \
	  docs/input.pdf docs/integrator.pdf docs/panel-mechanical.pdf \
	  docs/schematic.pdf docs/topass.pdf \
	  docs/patch?.png \
	  layout.kicad_wks coiler.kicad_pro coiler.kicad_sch coiler.kicad_pcb
