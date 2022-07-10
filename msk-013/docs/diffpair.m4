.PS 1.5
cct_init

Q1: bi_tr(up_ 0.6)
move to Q1.E
line down 0.1 then right 0.4 then up 0.1
Q2: bi_tr(up_ 0.6,R) with .E at Here

move to Q1.C
line up 0.1
dot(,,1)
move to Q2.C
line up 0.1
dot(,,1)

move to Q1.B
line left 0.1
dot(,,1)
move to Q2.B
line right 0.1
dot(,,1)

move to Q1.E+(0.2,-0.1)
dot
source(down_ 0.8,I)
dot(,,1)

.PE
