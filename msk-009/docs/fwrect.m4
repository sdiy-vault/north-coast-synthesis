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
R2: resistor(right_ 0.90)
dot
D1: diode(up_ 0.50)
corner
line left_ 0.05

move to R2.end
R3: resistor(right_ 0.75)
dot(,,1)

"R9\quad51k$\Omega$" at R1+(0,-0.15)
"R10\quad18k$\Omega$" at R2+(0,-0.15)
"R11\quad36k$\Omega$" at R3+(0,-0.15)
"D1" at D1+(0.18,0)
"U1A" at A1+(0.15,0.20)
.PE
