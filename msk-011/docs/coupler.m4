.PS 1.1
cct_init

C1: capacitor(right_ 0.5)
dot
R24: resistor(down_ 0.5)
ground
"C1\quad4.7$\mu$F" at C1.start+(0.32,0.12)
"R24" at R24.start+(0.16,-0.19)
"330k$\Omega$" at R24.start+(0.21,-0.31)

move to C1.start
dot(,,1)

move to C1.end
line right_ 0.25
dot(,,1)

.PE
