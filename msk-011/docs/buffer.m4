.PS 2
cct_init

Q1: bi_tr(up_)
rlabel(,\textrm{Q1},)

move to Q1.B
move left_ 0.1
R2: potentiometer(down_ 0.5)
move left_ 0.08
move up_ 0.05
"R2"
move down_ 0.1
move left_ 0.053
"100k$\Omega$"

move to R2.T1
line to Q1.B

move to R2.Start
line left_ 0.25
dot(,,1)

move to R2.End
ground

move to Q1.C
move up_ 0.07
"+12V"

move to Q1.E
R8: resistor(down_ 0.5)

move down_ 0.07
"$-$12V"

move to Q1.E
move down_ 0.20
move right_ 0.11
"R8"
move down_ 0.10
move right_ 0.040
"22k$\Omega$"

move to Q1.E
dot
line right_ 0.25
dot(,,1)

.PE
