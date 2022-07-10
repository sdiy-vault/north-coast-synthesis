.PS 3
cct_init

A1: opamp(right_,,,,R) with .W at Here

move to A1.In1
line left_ 0.25
X1: dot
line up_ 0.25
X2: dot
capacitor(right_ 0.667)
llabel(,\textrm{C6}~~0.1\mu\textrm{F},)
resistor(right_ 0.667)
llabel(,\textrm{R14}~~1\textrm{M}\Omega,)
corner
line down_ 0.375
dot
line down_ 0.375 then left_ 0.333
resistor(left_ 0.667)
llabel(,\textrm{R10}~~20\textrm{k}\Omega,)
line left_ 0.333
X3: dot
line up_ 0.25 then right_ 0.25

move to X1
capacitor(left_ 0.667)
llabel(,\textrm{C2}~~0.1\mu\textrm{F},)

move to X2
resistor(left_ 0.667)
rlabel(,\textrm{R6}~~1\textrm{M}\Omega,)
corner
line down_ 0.25
dot
ground(,,F)

move to X3
resistor(left_ 0.667)
llabel(,\textrm{R2}~~10\textrm{k}\Omega,)
corner
ground(,,F)

move to A1.Out
line right_ 0.6

.PE
