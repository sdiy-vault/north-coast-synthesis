.PS 5
cct_init

A1: opamp(right_,"","")

move to A1.Out+(-0.5,0)
line left_ 0.15
dot(,,1)
"$V_\textrm{HP}$" at Here+(-0.11,0)

"\large$A$" at A1.Out+(-0.35,0)

move to A1.Out
R1: resistor(right_ 0.5)
dot
line up_ 0.125
corner
L1: inductor(right_ 0.5)
dot
line down_ 0.25
dot
C1: capacitor(left_ 0.5)
corner
line up_ 0.125

"0.09" at R1.start+(0.25,0.10)
"22" at L1.start+(0.25,0.10)
"0.01" at C1.start+(-0.25,-0.14)

move to L1.end
line right_ 0.35
A2: opamp(right_) with .In1 at Here

move to A2.In2
line left_ 0.15
corner
ground

move to C1.start
line down_ 0.4
corner
C2: capacitor(right_ 0.5)
R2: resistor(right_ 0.5)
corner
line up_ 0.525
D1: dot
line left_ 0.15

"27" at R2.start+(0.25,-0.10)
"6.8" at C2.start+(0.25,-0.14)

move to D1
line right_ 0.15
dot(,,1)
"$V_\textrm{BP}$" at Here+(0.11,0)

.PE
