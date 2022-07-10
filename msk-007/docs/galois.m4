.PS
log_init

G1: XOR_gate at Here

R1: box ht 0.2 wid 0.2 with .w at G1.Out

R2: box ht 0.2 wid 0.2 with .w at R1.e

R3: box ht 0.2 wid 0.2 with .w at R2.e

move to R3.e
line right_ 0.1 then down_ 0.07 then right_ 0.15
G2: XOR_gate with .In2 at Here

R4: box ht 0.2 wid 0.2 with .w at G2.Out

move to R4.e
line right_ 0.1 then down_ 0.07 then right_ 0.15
G3: XOR_gate with .In2 at Here

R5: box ht 0.2 wid 0.2 with .w at G3.Out

move to G1.In2
line left_ 0.15
dot(,,1)

move to R5.e
line right_ 0.1
dot
line right_ 0.15
dot(,,1)

move to R5.e
move right_ 0.1
line up_ 0.4 then left_ 2.82 then down_ 0.35 then right_ 0.1

move to G2.In1
line left_ 0.09 then up_ 0.327
dot

move to G3.In1
line left_ 0.09 then up_ 0.327
dot

.PE
