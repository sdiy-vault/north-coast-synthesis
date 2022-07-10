# $Id: Makefile 10125 2022-06-03 15:19:05Z mskala $

#
# MSK 007 source package Makefile
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

all: msk-007.pdf

msk-007.pdf: $(wildcard docs/*.pdf) $(wildcard docs/*.tex) \
  $(wildcard docs/*.jpg) $(wildcard docs/*.m4) \
  docs/bomdata.tex docs/bomdata-1.tex docs/bomdata-2.tex docs/bomdata-3.tex
	$(MAKE) -C docs msk-007.pdf panel-art.png
	cp docs/msk-007.pdf .

docs/bomdata.tex: csv2tex leapfrog.csv
	./csv2tex leapfrog.csv > docs/bomdata.tex

docs/bomdata-1.tex: csv2tex leapfrog-1.csv
	./csv2tex leapfrog-1.csv > docs/bomdata-1.tex

docs/bomdata-2.tex: csv2tex leapfrog-2.csv
	./csv2tex leapfrog-2.csv > docs/bomdata-2.tex

docs/bomdata-3.tex: csv2tex leapfrog-3.csv
	./csv2tex leapfrog-3.csv > docs/bomdata-3.tex

msk-007.zip: msk-007.pdf voct/voct-0.1.tar.gz
	cp voct/voct-0.1.tar.gz .
	rm -f msk-007.zip
	zip -r msk-007.zip \
	  msk-007.pdf COPYING Makefile \
	  csv2tex *.csv \
	  docs/Makefile docs/*.jpg docs/patch?.png \
	  docs/adjustment.tex docs/board1.tex docs/board2.tex \
	  docs/board3.tex docs/bom.tex docs/calculations.tex \
	  docs/board3-silk.eps \
	  docs/circuit.tex docs/coretopo.m4 docs/cvproc.eps \
	  docs/diffpair.tex docs/drawings.tex docs/fibonacci.m4 \
	  docs/fibsv.m4 docs/galois.m4 docs/galsv.m4 docs/general.tex \
	  docs/integrator.eps \
	  docs/linca.m4 docs/msk-007.tex docs/panel-art.tex \
	  docs/outmixer.eps docs/powerref.eps \
	  docs/panel-master.tex docs/panel-mockup.tex docs/passivelc.m4 \
	  docs/patches.tex docs/preadjustment.tex docs/simplres.m4 \
	  docs/vca.eps \
	  docs/warnings.tex docs/topass.pdf docs/botass.pdf \
	  docs/mechanical2.pdf docs/panel-mechanical.pdf \
	  docs/schematic.pdf \
	  docs/exploded.pdf docs/panel-mechanical.dxf \
	  docs/mnelp-bode.gp docs/helper1.dat docs/panel-mnelp.gp \
	  docs/ncmanual.cls \
	  layout.kicad_wks leapfrog.kicad_pro leapfrog.kicad_sch leapfrog.kicad_pcb \
	  voct-0.1.tar.gz

voct/voct: voct/voct.c
	$(MAKE) -C voct voct

voct/voct-0.1.tar.gz: voct/voct
	$(MAKE) -C voct dist
