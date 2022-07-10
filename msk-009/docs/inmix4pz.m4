.PS 3
cct_init

A1: opamp(right_)

move to A1.In2
line left_ 0.15
corner
ground

move to A1.In1
line left_ 0.35
dot
R1: resistor(left_ 0.5)
D1: dot(,,1)
"100" at D1+(0.25,0.1)
"$V_\textrm{IN}$" at D1+(-0.12,0)

move to R1.start
line down_ 0.3
dot
R2: resistor(left_ 0.5)
D2: dot(,,1)
"51" at D2+(0.25,0.1)
"$V_\textrm{BP}$" at D2+(-0.12,0)

move to R2.start
line down_ 0.3
dot
R3: resistor(left_ 0.5)
D3: dot(,,1)
"100" at D3+(0.25,0.1)
"$V_\textrm{LP}$" at D3+(-0.12,0)

move to R3.start
R4: resistor(right_ 1.0)
D4: dot
line up_ 0.475
D5: dot
line left_ 0.155
"100" at D4+(-0.5,0.1)

move to D5
line right_ 0.25
D6: dot(,,1)
"$V_\textrm{HP}$" at D6+(0.12,0)

move to R4.start
line down_ 0.3
corner
C1: capacitor(right_ 1.0)
corner
line up_ 0.3

"0.033" at D4+(-0.5,-0.17)

.PE
