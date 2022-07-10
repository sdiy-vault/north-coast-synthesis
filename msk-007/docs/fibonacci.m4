.PS
log_init

G1: XOR_gate(3) at Here

R1: box ht 0.2 wid 0.2 with .w at G1.Out

R2: box ht 0.2 wid 0.2 with .w at R1.e

R3: box ht 0.2 wid 0.2 with .w at R2.e

R4: box ht 0.2 wid 0.2 with .w at R3.e

move to R4.e
line right_ 0.2
dot
line right_ 0.2

R5: box ht 0.2 wid 0.2 with .w at Here

move to R5.e
line right_ 0.2
dot
line right_ 0.2
dot(,,1)

move to G1.In3
line left_ 0.3
dot(,,1)

move to R4.e
move right_ 0.2
line up_ 0.3 then left_ 1.5 then down_ 0.2 then right 0.11

move to R5.e
move right_ 0.2
line up_ 0.45 then left_ 2.25 then down_ 0.45 then right 0.275

.PE
