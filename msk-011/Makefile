# $Id: Makefile 5976 2018-03-27 16:08:27Z mskala $

#
# MSK 011 source package Makefile
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

all: msk-011.pdf

msk-011.pdf: $(wildcard docs/*.pdf) $(wildcard docs/*.tex) \
  $(wildcard docs/*.jpg) $(wildcard docs/*.m4) \
  docs/bomdata.tex
	$(MAKE) -C docs msk-011.pdf panel-art.png
	cp docs/msk-011.pdf .

docs/bomdata.tex: csv2tex discrmix.csv
	./csv2tex discrmix.csv > docs/bomdata.tex

msk-011.zip: msk-011.pdf
	rm -f msk-011.zip
	zip -r msk-011.zip \
	  msk-011.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/ncmanual.cls \
	  docs/adjustment.tex docs/assembly.tex docs/bom.tex \
	  docs/circuit.tex docs/drawings.tex docs/general.tex \
	  docs/msk-011.tex docs/panel-*.tex docs/patches.tex \
	  docs/warnings.tex \
	  docs/*.dxf docs/*.jpg docs/*.m4 docs/patch?.png \
	  docs/botass.pdf docs/exploded.pdf docs/panel-mechanical.pdf \
	  docs/schematic.pdf docs/topass.pdf \
	  layout.kicad_wks discrmix.kicad_pro discrmix.kicad_sch \
	  discrmix.kicad_prl discrmix.kicad_pcb
