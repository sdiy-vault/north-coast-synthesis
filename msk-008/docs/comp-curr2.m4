.PS 2.8
cct_init

OA1: opamp

move to OA1.In1
line left_ 0.2
"$V_\textrm{q}$" at Here+(-0.10,0)

move to OA1.In2
line left_ 0.2
"$+$0.50V" at Here+(-0.20,0)

move to OA1.Out
dot
line right_ 0.100
diode(right_ 0.200,,R)
llabel(,\textrm{D13},)
R19: resistor(right_ 0.700)
rlabel(,\textrm{R19}~~47\textrm{k}\Omega,)
dot
R29: resistor(right_ 0.500)
llabel(,\textrm{R29}~~499\textrm{k}\Omega,)
"$I_\textrm{out}$" at Here+(0.13,0)

move to R29.start
line down_ 0.25
corner
diode(right_ 0.500,,R)
llabel(,\textrm{D2},)
"$-$4.50V" at Here+(0.04,-0.10)

move to OA1.Out
line down_ 0.50
corner
diode(right_ 0.400,,R)
llabel(,\textrm{D14},)
line right_ 1.100
"$I_\textrm{LED}$" at Here+(0.13,0)

.PE
