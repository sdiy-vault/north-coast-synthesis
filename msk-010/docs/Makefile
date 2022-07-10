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
	pdftoppm -png panel-art.pdf > panel-art.png

fakevdiv.tex: fakevdiv.pic
fakevdiv.pic: fakevdiv.m4
gain3.tex: gain3.pic
gain3.pic: gain3.m4
gain32.tex: gain32.pic
gain32.pic: gain32.m4
vdiv.tex: vdiv.pic
vdiv.pic: vdiv.m4
wienbridge.tex: wienbridge.pic
wienbridge.pic: wienbridge.m4
zeners.tex: zeners.pic
zeners.pic: zeners.m4

ncmanual.cls: ../../kicad-symbols/ncmanual.cls
	cp ../../kicad-symbols/ncmanual.cls .

msk-010.pdf: *.tex ncmanual.cls \
  fakevdiv.tex gain3.tex gain32.tex vdiv.tex wienbridge.tex zeners.tex
