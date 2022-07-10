.PS 3.0
cct_init

OA1: opamp(right_ 0.333,,,0.333)

move to OA1.In1
line left_ 0.167
corner
line up_ 0.333
corner

R41: resistor(right_ 0.667)
rlabel(,\textrm{R41}~100\textrm{k}\Omega,)
R42: resistor(right_ 0.667)
rlabel(,\textrm{R42}~100\textrm{k}\Omega,)
R43: resistor(right_ 0.667)
rlabel(,\textrm{R43}~100\textrm{k}\Omega,)

move to OA1.Out
line right_ 0.167
corner
line up_ 0.420

move to R43.start
line down_ 0.333
corner
line right_ 0.167
OA2: opamp(right_ 0.333,,,0.333) with .In1 at Here

move to OA2.Out
line right_ 0.167
corner
line up_ 0.420

move to R41.start
dot(,,1)
"$I_1$" at Here+(0,0.08)

move to R42.start
dot(,,1)
"$V_1$" at Here+(0,0.08)

move to R43.start
dot(,,1)
"$I_2$" at Here+(0,0.08)

move to R43.end
dot(,,1)
"$V_2$" at Here+(0,0.08)

move to OA1.In2
line left_ 0.167
corner
ground

move to OA2.In2
line left_ 0.167
corner
ground

.PE
