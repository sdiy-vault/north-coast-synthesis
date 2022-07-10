.PS 2.5
cct_init

R30R31: resistor(up_ 0.667);
llabel(,,\scriptsize\textrm{R30+R31})

line right_ 0.5
dot
line right_ 0.5

R43R44: resistor(down_ 0.667)
rlabel(\scriptsize\textrm{R43+R44},,)
dot
RGND: resistor(down_ 0.667)
rlabel(,,\textrm{70.5k}\Omega)

line right_ 0.5

resistor(up_ 0.667)
llabel(\textrm{70.5k}\Omega,,)
dot
R32R33: resistor(up_ 0.667)
llabel(,,\scriptsize\textrm{R32+R33})

line right_ 0.25
dot
line right_ 0.25

R38R39: resistor(down_ 0.667)
rlabel(\scriptsize\textrm{R38+R39},,)
dot(,,1)
move down_ 0.10
"P13"

move to R30R31.start
dot(,,1)
move down_ 0.10
"P8"

move to RGND.end
dot
ground(,,F)

move to RGND.end
line left_ 0.5
resistor(up_ 0.667)
llabel(\textrm{70.5k}\Omega,,)
dot
R34R35: resistor(up_ 0.667)
llabel(,,\scriptsize\textrm{R34+R35})

move to R34R35.start
line right_ 0.15
dot(,,1)
move down_ 0.10
"P10"

move to R43R44.end
line right_ 0.15
dot(,,1)
move down_ 0.10
"P16"

move to R32R33.start
line right_ 0.15
dot(,,1)
move down_ 0.10
"P9"

move to R30R31.end
move right_ 0.5
line up_ 0.15
dot(,,1)
move up_ 0.10
"P22"

move to R32R33.end
move right_ 0.25
line up_ 0.15
dot(,,1)
move up_ 0.10
"P23"

.PE
