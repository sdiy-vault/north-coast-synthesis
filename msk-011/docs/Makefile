# $Id: Makefile 5976 2018-03-27 16:08:27Z mskala $

define lu-define-flavor-XELATEX
  $$(eval $$(call lu-create-flavor,XELATEX,tex,XELATEX,.pdf,pdf,\
    .pdftex_t .$$(_LU_XELATEX_EXT)))
endef

LU_FLAVORS=XELATEX
XELATEX=xelatex

include LaTeX.mk

%.pic: %.m4
	m4 -I /usr/local/share/texmf/tex/latex/circuit_macros \
	  pgf.m4 $*.m4 > $*.pic

%.tex: %.pic
	dpic -g $*.pic > $*.tex

%.eps: %.gp
	gnuplot $*.gp

panel-art.png: panel-art.pdf
	pdftoppm -r 300 -png panel-art.pdf > panel-art.png

ncmanual.cls: ../../kicad-symbols/ncmanual.cls
	cp ../../kicad-symbols/ncmanual.cls .

msk-011.pdf: ncmanual.cls \
  buffer.tex coupler.tex mixer.tex outamp.tex transistor.tex \
  panel-mockup.pdf
