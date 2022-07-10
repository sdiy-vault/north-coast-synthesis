.PS 3
cct_init

Mixer: amp
dot
I1: amp
dot
I2: amp

move to Mixer
move left_ 0.10
"$\Sigma$"

move to I1
move left_ 0.10
move down_ 0.015
"$\int$"

move to I2
move left_ 0.10
move down_ 0.015
"$\int$"

move to Mixer.start
move up_ 0.15 right 0.12
line left_ 0.25
dot(,,1)
move left_ 0.13
"$\textit{IN}$"

move to Mixer.end
line down_ 0.5
dot(,,1)
move down_ 0.12
"$\textit{HP}$"

move to I1.end
line down_ 0.5
dot(,,1)
move down_ 0.12
"$\textit{BP}$"

move to I2.end
line down_ 0.5
dot(,,1)
move down_ 0.12
"$\textit{LP}$"

move to I1.end
move down_ 0.3
dot
line left_ 1.47
corner
line up_ 0.15
corner
line right_ 0.09

move to I2.end
move down_ 0.4
dot
line left_ 2.33
corner
line up_ 0.4
corner
line right_ 0.12

.PE
