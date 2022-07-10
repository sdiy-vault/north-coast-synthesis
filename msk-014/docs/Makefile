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

success.cropped.eps: success.ly
	lilypond -dno-point-and-click -dcrop -feps success.ly 

failure.cropped.eps: failure.ly
	lilypond -dno-point-and-click -dcrop -feps failure.ly 

.PRECIOUS: success.cropped.eps failure.cropped.eps

msk-014-user.pdf: \
  ncmanual.cls success.cropped.eps failure.cropped.eps panel-mockup.pdf

msk-014-prog.pdf: \
  ncmanual.cls
