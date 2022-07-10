.PS 3
cct_init

A1: opamp(right_,,,0.4)

move to A1.In2
line left_ 0.2
corner
ground

move to A1.In1
line left_ 0.4
corner
line down_ 0.6
dot
R1: resistor(left_ 0.75)
dot(,,1)

move to R1.start
C1: capacitor(right_ 0.90)
dot
line up_ 0.50
corner
line left_ 0.05

move to C1.end
line right_ 0.15
dot(,,1)

.PE
