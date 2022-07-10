.PS 3
cct_init

Mixer: opamp(right_,"","") with .W at Here

move to Mixer.Out
line right_ 0.1

I1: opamp(right_,"","") with .W at Here
move to I1.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I1.Out
line right_ 0.1
dot
line right_ 0.1

I2: opamp(right_,"","") with .W at Here
move to I2.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I2.Out
line right_ 0.1
dot
line right_ 0.1

I3: opamp(right_,"","") with .W at Here
move to I3.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I3.Out
line right_ 0.1
dot
line right_ 0.1

I4: opamp(right_,"","") with .W at Here
move to I4.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I4.Out
line right_ 0.1
dot
line right_ 0.1

I5: opamp(right_,"","") with .W at Here
move to I5.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I5.Out
line right_ 0.1
dot
line right_ 0.1
dot(,,1)

move to Mixer.C
move left_ 0.10
"\small$\Sigma$"

move to Mixer.W
move down_ 0.15
line left_ 0.4
dot(,,1)

move to Mixer.W
move down_ 0.09
line left_ 0.34 then up_ 0.63 then right_ 4.34 then down_ 0.52

move to Mixer.W
move down_ 0.03
line left_ 0.30 then up_ 0.51 then right_ 3.60 then down_ 0.46

move to Mixer.W
move up_ 0.03
line left_ 0.26 then up_ 0.39 then right_ 2.86 then down_ 0.40

move to Mixer.W
move up_ 0.09
line left_ 0.22 then up_ 0.27 then right_ 2.12 then down_ 0.34

move to Mixer.W
move up_ 0.15
line left_ 0.18 then up_ 0.15 then right_ 1.38 then down_ 0.28

.PE
