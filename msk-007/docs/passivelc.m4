.PS 3
cct_init

S: source(up_ 0.667,AC)
resistor(right_ 0.667)
b_current(I_{\textrm{in}})
dot
L1: inductor(right_ 1.0)
b_current(I_1)
rlabel(,L_1)
dot
L2: inductor(right_ 1.0)
b_current(I_2)
rlabel(,L_2)
dot
line right_ 0.5
resistor(down_ 0.667)
ground(,,F)

move to S.start
ground(,,F)

move to L1.start
capacitor(down_ 0.667)
llabel(,,C_1)
ground(,,F)

move to L2.start
capacitor(down_ 0.667)
llabel(,,C_2)
ground(,,F)

move to L2.end
capacitor(down_ 0.667)
llabel(,,C_3)
ground(,,F)

move to L1.start
move up_ 0.097
"$V_1$"

move to L2.start
move up_ 0.097
"$V_2$"

move to L2.end
move up_ 0.097
"$V_3$"

.PE
