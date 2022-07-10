.PS 5
cct_init

R1A: resistor(down_ 0.4)
llabel(,R_1,)
rarrow(I_1)
line down_ 0.2
R2A: resistor(down_ 0.4)
llabel(,R_2)
dot
D1A: diode(down_ 0.5)
ground
em_arrows(,315) with .Tail at D1A.end+(0.07,0.17)

"$+$11.8V" at R1A.start+(0,0.05)

move to D1A.start
line left_ 0.2
"$+$2.15V" at Here+(-0.07,-0.07)

move to R1A.start+(0.75,0)
R1B: resistor(down_ 0.4)
llabel(,R_1,)
rarrow(I_2)
line down_ 0.1
dot
line down_ 0.1
R2B: resistor(down_ 0.4)
llabel(,R_2)
D1B: diode(down_ 0.5)
rarrow(0~~)
ground
em_arrows(,315) with .Tail at D1B.end+(0.07,0.17)

move to R1B.end+(0,-0.1)
line right_ 0.5
corner
line down_ 0.1
R3B: resistor(down_ 0.4)
llabel(,R_3,)
rarrow(I_2)

"$+$11.8V" at R1B.start+(0,0.05)
"$V_1$" at R1B.end+(-0.08,-0.12)
"$-$10.6V" at R3B.end+(0,-0.07)

move to R1B.start+(1.25,0)
R1C: resistor(down_ 0.4)
llabel(,R_1,)
rarrow(I_3)
line down_ 0.1
dot
line down_ 0.15
R2C: resistor(down_ 0.3)
llabel(,R_2)
rarrow(I_4,<-)
line down_ 0.05
dot
D1C: diode(down_ 0.5)
ground
em_arrows(,315) with .Tail at D1C.end+(0.07,0.17)

move to R1C.end+(0.5,-0.1)
dot
line down_ 0.1
R3C: resistor(down_ 0.4)
llabel(,R_3,)
rarrow(I_5)

move to R1C.end+(0,-0.1)
line right_ 1.0
corner
line down_ 0.1
R4C: resistor(down_ 0.4)
llabel(,R_4,)
rarrow(I_6)

"$+$11.8V" at R1C.start+(0,0.05)
"$V_2$" at R1C.end+(-0.08,-0.12)
"$-$10.6V" at R3C.end+(0,-0.07)
"$-$10.6V" at R4C.end+(0,-0.07)

move to D1C.start
line left_ 0.2
"$-$1.75V" at Here+(-0.07,-0.07)

.PE
