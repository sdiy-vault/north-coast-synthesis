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
move left_ 0.75
L1: inductor(right_ 0.75,,,P)
move left_ 0.75
dot(,,1)

move to L1.end
R1: resistor(right_ 0.90)
dot
line up_ 0.50
corner
line left_ 0.05

move to R1.end
line right_ 0.15
dot(,,1)

.PE
