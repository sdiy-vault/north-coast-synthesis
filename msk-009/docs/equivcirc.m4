.PS 3
cct_init

R1: resistor(right_ 0.6667)
dot
line up_ 0.15
corner
L1: inductor(right_ 0.6667)
corner
line down_ 0.15
dot
line down_ 0.15
corner
C1: capacitor(left_ 0.6667)
corner
line up_ 0.15

move to R1.start
dot(,,1)

move to L1.end
move down_ 0.15
line right_ 0.15
dot(,,1)

"90$\Omega$" at R1+(0,0.10)
"22mH" at L1+(0,0.10)
"10pF" at C1+(0.15,0.07)

.PE
