.PS 3
cct_init

I1: opamp(right_,~~\scriptsize$+$,~~\scriptsize$+$) with .W at Here

move to I1.In2
line left_ 0.25
dot(,,1)

move to I1.Out
line right_ 0.25 then down_ 0.125 then right_ 0.25

I2: opamp(right_,~~\scriptsize$+$,~~\scriptsize$+$) with .In2 at Here

move to I2.Out
line right_ 0.25 then down_ 0.125 then right_ 0.25

I3: opamp(right_,~~\scriptsize$+$,~~\scriptsize$+$) with .In2 at Here

move to I3.Out
line right_ 0.25 then down_ 0.125 then right_ 0.25

I4: opamp(right_,~~\scriptsize$+$,~~\scriptsize$+$) with .In2 at Here

move to I4.Out
line right_ 0.25 then down_ 0.125 then right_ 0.25

I5: opamp(right_,~~\scriptsize$+$,~~\scriptsize$+$) with .In2 at Here

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

move to I5.Out
line right_ 0.15
dot
line right 0.15
dot(,,1)

move to I5.Out
move right_ 0.15
line up_ 0.4 then left_ 4.76 then down_ 0.280 then right_ 0.1

move to I2.In1
line left_ 0.1 then up_ 0.277
dot

move to I3.In1
line left_ 0.1 then up_ 0.277
dot

move to I4.In1
line left_ 0.1 then up_ 0.277
dot

move to I5.In1
line left_ 0.1 then up_ 0.277
dot

.PE
