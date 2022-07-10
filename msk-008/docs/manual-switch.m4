.PS 3
cct_init

R1: resistor(right_ 0.667)
llabel(,\textrm{R14}~~75\textrm{k}\Omega,)
dot
R2: resistor(right_ 0.667)
llabel(,\textrm{R15}~~1\textrm{M}\Omega,)
dot(,,1)
"SW" at Here+(0,-0.07)

move to R1.start
dot(,,1)
"$V_\textrm{in}$" at Here+(0,-0.07)

move to R2.start
line down_ 0.15
dot(,,1)
"$V_\textrm{q}$" at Here+(0.07,-0.01)

.PE
