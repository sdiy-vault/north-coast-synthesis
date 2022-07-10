.PS 2
cct_init

Q1: bi_tr(up_)

move to Q1.E
ground

move to Q1.C
R1: resistor(up_ 0.5)
rlabel(,~39\textrm{k}\Omega,)
move to R1.end
move up_ 0.07
"+12V"

move to Q1.C
dot
line right_ 0.333
line down_ 0.25
Q2: bi_tr(up_) with .B at Here

move to Q2.E
ground

move to Q2.C
R2: resistor(up_ 0.5)
rlabel(,~39\textrm{k}\Omega,)
move to R2.end
move up_ 0.07
"+12V"

move to Q2.C
dot
line right_ 0.30
line down_ 0.85
line left_ 1.28
line up_ 0.60

.PE
