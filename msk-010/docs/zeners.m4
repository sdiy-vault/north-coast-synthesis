.PS 3
cct_init

A1: opamp(right_,,,,R) with .W at Here

move to A1.In1
line left_ 0.5
dot(,,1)

move to A1.Out
line right_ 0.75
X2: dot
line down_ 0.375
X4: dot
line left_ 0.667
resistor(left_ 0.667)
llabel(,\textrm{R10}~~22\textrm{k}\Omega,)
line left_ 0.667
X3: dot
line up_ 0.25 then right_ 0.75

move to X2
line right_ 0.25
dot(,,1)

move to X3
resistor(left_ 0.667)
rlabel(,\textrm{R2}~~10\textrm{k}\Omega,)
corner
ground(,,F)

move to X4
line down_ 0.35
corner
resistor(left_ 0.667)
llabel(,\textrm{R18}~~27\textrm{k}\Omega,)
diode(left_ 0.667,Z,R)
llabel(,\textrm{D6}~~4.3\textrm{V},)
diode(left_ 0.667,Z)
llabel(,\textrm{D2}~~4.3\textrm{V},)
corner
line up_ 0.35

.PE
