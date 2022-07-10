.PS 1
cct_init

Q1: bi_tr(up_)

move to Q1.B
line left_ 0.1
dot(,,1)

move to Q1.E
ground

move to Q1.C
dot
line right_ 0.25
dot(,,1)

move to Q1.C
R1: resistor(up_ 0.5)
rlabel(,~39\textrm{k}\Omega,)
move to R1.end
move up_ 0.07
"+12V"

.PE
