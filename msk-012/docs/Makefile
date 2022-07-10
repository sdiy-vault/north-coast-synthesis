# $Id: Makefile 6095 2018-06-22 22:01:45Z mskala $

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

msk-012.pdf: ncmanual.cls bistable.tex rtlinv.tex \
  panel-mockup.pdf


