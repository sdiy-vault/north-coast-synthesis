.PS 2
cct_init

R12: resistor(right_ 0.5)
line down_ 0.6
"R12\quad47k$\Omega$" at R12.end+(-0.25,0.08)

move to R12.start
dot(,,1)

move to R12.end
move down_ 0.2
dot
R13: resistor(left_ 0.5)
dot(,,1)
"R13\quad47k$\Omega$" at R13.start+(-0.25,0.08)

move to R13.start
move down_ 0.2
dot
R14: resistor(left_ 0.5)
dot(,,1)
"R14\quad47k$\Omega$" at R14.start+(-0.25,0.08)

move to R14.start
move down_ 0.2
dot
R15: resistor(left_ 0.5)
dot(,,1)
"R15\quad47k$\Omega$" at R15.start+(-0.25,0.08)

move to R15.start
R16: resistor(down_ 0.5)
R7: potentiometer(right_ 0.5)
"R16" at R16.start+(-0.13,-0.22)
"330k$\Omega$" at R16.start+(-0.16,-0.28)
"R7\quad100k$\Omega$" at R7.Start+(0.25,-0.08)
"$+$12V" at R7.Start+(-0.10,0)
"$-$12V" at R7.End+(0.10,0)

move to R15.start
line right_ 0.333
dot
R17: resistor(down_ 0.5)
"$-$12V" at Here+(0,-0.06)
"R17" at R17.start+(0.12,-0.22)
"2.7k$\Omega$" at R17.start+(0.15,-0.28)

move to R17.start
line right_ 0.20
dot(,,1)

.PE
