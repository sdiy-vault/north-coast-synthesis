.PS 2.5
cct_init

R1: resistor(right_ 0.5); llabel(,\textrm{270}\Omega,)
dot
R2: resistor(down_ 0.5); llabel(,\textrm{100}\Omega,)
ground

move to R1.start
dot(,,1)

move to R1.end
line right 0.2
Q1: bi_tr(down_ 0.6,R,P) with .B at Here

move to Q1.E
line right 0.3
ground

move to Q1.C
resistor(down_ 0.5); llabel(,\textrm{6.8k}\Omega,)

"$-$12V" at Here+(0.00,-0.06)

.PE
