.PS 3
cct_init

A1: opamp(right_,,,,R) with .W at Here

move to A1.In1
line left_ 0.5
dot(,,1)

move to A1.Out
line right_ 0.25
X2: dot
line down_ 0.375
corner
line left_ 0.167
resistor(left_ 0.667)
llabel(,\textrm{R10}~~20\textrm{k}\Omega,)
line left_ 0.167
X3: dot
line up_ 0.25 then right_ 0.25

move to X2
line right_ 0.25
dot(,,1)

move to X3
resistor(left_ 0.667)
llabel(,\textrm{R2}~~10\textrm{k}\Omega,)
corner
ground(,,F)

.PE
