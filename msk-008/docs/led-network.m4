.PS 2.6
cct_init

R49: resistor(right_ 0.667)
llabel(,\textrm{R49}~~1.2\textrm{k}\Omega,)
dot
R53: resistor(right_ 0.667)
llabel(,\textrm{R53}~~910\Omega,)

move to R49.start+(0,-0.333)
R50: resistor(right_ 0.667)
llabel(,\textrm{R50}~~910\Omega,)
dot
D11: diode(right_ 0.667)
llabel(,\textrm{D11},)
corner
ground
em_arrows(,45) with .Tail at D11.end+(-0.22,0.05)

move to R53.start
line down_ 0.333

"$V_\textrm{q}>+0.5\textrm{V}$" at R49.start+(-0.02,-0.06)
"$V_\textrm{q}>-0.5\textrm{V}$" at R50.start+(-0.02,-0.06)
"$+$12V" at R53.end+(0.10,0)

.PE
