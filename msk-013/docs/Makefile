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

msk-013.pdf: \
  ncmanual.cls panel-mockup.pdf shaper-combined.pdf \
  sin.pdf cos.pdf both.pdf \
  bk3.png bk4.png bk5.png bk6.png bk7.png bk8.png bk9.png \
  diffpair.tex expo-q.tex parabolas.tex \
  current-ref.eps expo-con.eps pulse-shaper.eps saw-shaper.eps \
  sh-core.pdf sh-csink.pdf sh-inmix.pdf sh-outmix-both.pdf sh-outmix-sin.pdf \
  tri-core.pdf

shaper-combined.eps: shaper-combined.gp
