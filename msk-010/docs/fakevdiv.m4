.PS 3
cct_init

X1: resistor(right_ 0.667)
llabel(,\textrm{R14}~~1\textrm{M}\Omega,)
resistor(right_ 0.667)
llabel(,\textrm{C6}~~``1\textrm{M}\Omega'',)
X2: dot
line right_ 0.25
X3: dot
line right_ 0.25
dot(,,1)

move to X1.start
dot(,,1)

move to X2
resistor(down_ 0.667)
rlabel(\textrm{R10}~~,,1\textrm{M}\Omega~~)
ground(,,F)

move to X3
resistor(down_ 0.667)
llabel(~~\textrm{C2},,~~``1\textrm{M}\Omega'')
ground(,,F)

.PE
