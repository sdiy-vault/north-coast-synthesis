# $Id: Makefile 10136 2022-06-04 19:09:28Z mskala $

#
# MSK 012 source package Makefile
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

all: msk-012.pdf

msk-012.pdf: $(wildcard docs/*.pdf) $(wildcard docs/*.tex) \
  $(wildcard docs/*.jpg) $(wildcard docs/*.m4) $(wildcard docs/*.png) \
  $(wildcard docs/*.eps) \
  docs/bomdata.tex
	$(MAKE) -C docs msk-012.pdf panel-art.png
	cp docs/msk-012.pdf .

docs/bomdata.tex: csv2tex qadsr.csv
	./csv2tex qadsr.csv > docs/bomdata.tex

msk-012.zip: msk-012.pdf
	rm -f msk-012.zip
	zip -r msk-012.zip \
	  msk-012.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/ncmanual.cls \
	  docs/assembly.tex docs/bom.tex docs/circuit.tex \
	  docs/drawings.tex docs/general.tex docs/msk-012.tex \
	  docs/panel-*.tex docs/patches.tex docs/testing.tex \
	  docs/warnings.tex \
	  docs/*.dxf docs/*.eps docs/*.jpg docs/*.m4 \
	  docs/botass.pdf docs/exploded.pdf docs/panel-mechanical.pdf \
	  docs/schematic.pdf docs/topass.pdf \
	  docs/BK000032.png docs/patch?.png \
	  layout.kicad_wks qadsr.kicad_pro qadsr.kicad_prl \
	  qadsr.kicad_sch qadsr.kicad_pcb
