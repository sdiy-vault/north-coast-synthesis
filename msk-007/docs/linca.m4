.PS
log_init

R1: box ht 0.2 wid 0.2 at (0,0)
R2: box ht 0.2 wid 0.2 at (0.5,0)
R3: box ht 0.2 wid 0.2 at (1.0,0)
R4: box ht 0.2 wid 0.2 at (1.5,0)
R5: box ht 0.2 wid 0.2 at (2.0,0)

down_
G1: XOR_gate with .Out at R1.n
G2: XOR_gate with .Out at R2.n
G3: XOR_gate with .Out at R3.n
G4: XOR_gate with .Out at R4.n
G5: XOR_gate with .Out at R5.n

move to G1.In2
line up_ 0.12 then left_ 0.2
dot(,,1)

move to R1.s
line down_ 0.1 then right_ 0.3 then up_ 0.8 then right_ 0.1 then down_ 0.12

move to R2.s
line down_ 0.2
dot
line right_ 0.3 then up_ 0.9 then right_ 0.1 then down_ 0.12

move to R3.s
line down_ 0.1
dot
line right_ 0.3 then up_ 0.8 then right_ 0.1 then down_ 0.12

move to R4.s
line down_ 0.2
dot
line right_ 0.3 then up_ 0.9 then right_ 0.1 then down_ 0.12

move to R2.s
move down_ 0.2
line left_ 0.3 then up_ 0.9 then left_ 0.1 then down_ 0.12

move to R3.s
move down_ 0.1
line left_ 0.3 then up_ 0.8 then left_ 0.1 then down_ 0.12

move to R4.s
move down_ 0.2
line left_ 0.3 then up_ 0.9 then left_ 0.1 then down_ 0.12

move to R5.s
line down_ 0.1
dot
line left_ 0.3 then up_ 0.8 then left_ 0.1 then down_ 0.12

move to R5.s
move down_ 0.1
line right_ 0.2
dot(,,1)

move to R3.s
move left_ 0.3
move up_ 0.7
dot
line up_ 0.1 then right_ 0.3 then down_ 0.23

move to R4.s
move left_ 0.3
move up_ 0.7
dot
line up_ 0.1 then right_ 0.3 then down_ 0.23

.PE
