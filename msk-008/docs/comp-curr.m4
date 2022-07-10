.PS 2.8
cct_init

OA1: opamp

move to OA1.In1
line left_ 0.2
"$V_\textrm{q}$" at Here+(-0.10,0)

move to OA1.In2
line left_ 0.2
"$+$1.50V" at Here+(-0.20,0)

move to OA1.Out
R18: resistor(right_ 0.667)
llabel(,\textrm{R18}~~47\textrm{k}\Omega,)
dot
R28: resistor(right_ 0.667)
llabel(,\textrm{R28}~~499\textrm{k}\Omega,)
"$I_\textrm{out}$" at Here+(0.13,0)

move to R28.start
line down_ 0.25
corner
diode(right_ 0.667,,R)
rlabel(,\textrm{D1},)
"$-$4.50V" at Here+(0.04,-0.10)

.PE
