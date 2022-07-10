.PS 3
cct_init

I1: opamp(right_,,,,R) with .W at Here

move to I1.In1
line left_ 0.25
dot(,,1)

move to I1.Out
line right_ 0.25
dot
line up_ 0.125 then right_ 0.25

I2: opamp(right_,,,,R) with .In1 at Here

move to I2.Out
line right_ 0.25
dot
line up_ 0.125 then right_ 0.25

I3: opamp(right_,,,,R) with .In1 at Here

move to I3.Out
line right_ 0.25
dot
line up_ 0.125 then right_ 0.25

I4: opamp(right_,,,,R) with .In1 at Here

move to I4.Out
line right_ 0.25
dot
line up_ 0.125 then right_ 0.25

I5: opamp(right_,,,,R) with .In1 at Here

move to I1.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I2.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I3.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I4.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I5.C
move left_ 0.06
move down_ 0.015
"\small$\int$"

move to I2.Out
move right_ 0.25
line down_ 0.435 then left_ 1.875 then up_ 0.320 then right_ 0.125

move to I3.Out
move right_ 0.25
line down_ 0.535 then left_ 1.875 then up_ 0.420 then right_ 0.125

move to I4.Out
move right_ 0.25
line down_ 0.435 then left_ 1.875 then up_ 0.320 then right_ 0.125

move to I5.Out
line right_ 0.25 then down_ 0.535 then left_ 0.875
dot
line up_ 0.420 then right_ 0.125

move to I5.Out
move down_ 0.535
move left_ 0.625
line left_ 1.0 then up_ 0.420 then right_ 0.125

move to I3.Out
move right_ 0.250
move down_ 0.535
dot
line down_ 0.465 then right_ 1.250
Mixer: opamp(right_,"","") with .W at Here

move to I1.Out
move right_ 0.250
line down_ 1.180 then right_ 3.250

move to I2.Out
move right_ 0.250
move down_ 0.435
dot
line down_ 0.655 then right_ 2.250

move to I4.Out
move right_ 0.250
move down_ 0.435
dot
line down_ 0.475 then right_ 0.250

move to I5.Out
move down_ 0.535
move left_ 0.625
line down_ 0.285 then right_ 0.125

move to Mixer.Out
line right_ 0.25
dot(,,1)

move to Mixer.C
move left_ 0.10
"\small$\Sigma$"

.PE
