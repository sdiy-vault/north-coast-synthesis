.PS 3
cct_init

Q5: bi_tr(up_)
rlabel(,\textrm{Q5},)

move to Q5.B
line left_ 0.1
dot(,,1)

move to Q5.E
R19: resistor(down_ 0.5)
move down_ 0.07
"$-$12V"
"R19" at Q5.E+(0.13,-0.20)
"510$\Omega$" at Q5.E+(0.16,-0.30)

move to Q5.C
dot
R18: resistor(up_ 0.5)
move up_ 0.07
"$+$12V"
"R18" at Q5.C+(0.12,0.30)
"5.9k$\Omega$" at Q5.C+(0.16,0.20)

move to Q5.C
R20: resistor(right_ 0.5)
dot
R21: resistor(down_ 0.5)
move down_ 0.07
"$-$12V"
"R20\quad22k$\Omega$" at R20.start+(0.25,0.08)
"R21" at R21.start+(0.13,-0.20)
"12k$\Omega$" at R21.start+(0.15,-0.30)

move to R21.start+(0.25,0.25)
Q6: bi_tr(up_)
rlabel(,\textrm{Q6},)
move to R21.start
line to Q6.B

move to Q6.E
R23: resistor(down_ 0.5)
move down_ 0.07
"$-$12V"
"R23" at R23.start+(0.13,-0.20)
"510$\Omega$" at R23.start+(0.15,-0.30)

move to Q6.C
R22: resistor(up_ 0.5)
move up_ 0.07
"$+$12V"
"R22" at R22.start+(0.13,0.30)
"4.7k$\Omega$" at R22.start+(0.16,0.20)

move to Q6.C
dot
line right_ 0.25
dot(,,1)

.PE
