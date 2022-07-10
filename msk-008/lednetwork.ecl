:-lib(ic).

resistor_problem(V):-
  V=[R1,R2,R3,R4,
     V1,V2,
     I1,I2,I3,I4,I5,I6],
  % sourceable resistances
  [R1,R3,R4]$:: 10.0..1000000.0,R2$:: 0.0..1000000.0,
  % all currents in right direction and sanely scaled
  [I1,I2,I3,I4,I5,I6]$:: 1.0e-7..1.0e-1,
  % no voltages too near the rails
  [V1,V2]$:: -10.0..10.0,
  % combined Ohm/Kirchoff and voltage target for green state
  (11.8-2.15)$=I1*(R1+R2),
  % Ohm's law
  11.8-V1$=I2*R1,
  10.6+V1$=I2*R3,
  11.8-V2$=I3*R1,
  -1.75-V2$=I4*R2,
  10.6+V2$=I5*R3,
  10.6+V2$=I6*R4,
  % Kirchhoff's law
  I3+I4$=I5+I6,
  % LED targets
  I1$:: 0.010..0.020,
  I4$>= 0.20*I1,
  I4$=< 0.26*I1,
  V1$:: -1.0..1.0,
  % 339 current constraint (13mA)
  I2$=<0.013,
  I5$=<0.013,
  I6$=<0.013,
  % resistor power constraint (230mW)
  I1*I1*R1$=<0.230,
  I1*I1*R2$=<0.230,
  I2*I2*R1$=<0.230,
  I2*I2*R3$=<0.230,
  I3*I3*R1$=<0.230,
  I4*I4*R2$=<0.230,
  I5*I5*R3$=<0.230,
  I6*I6*R4$=<0.230.

e48_value(1.00).
e48_value(1.05).
e48_value(1.10).
e48_value(1.15).
e48_value(1.21).
e48_value(1.27).
e48_value(1.33).
e48_value(1.40).
e48_value(1.47).
e48_value(1.54).
e48_value(1.62).
e48_value(1.69).
e48_value(1.78).
e48_value(1.87).
e48_value(1.96).
e48_value(2.05).
e48_value(2.15).
e48_value(2.26).
e48_value(2.37).
e48_value(2.49).
e48_value(2.61).
e48_value(2.74).
e48_value(2.87).
e48_value(3.01).
e48_value(3.16).
e48_value(3.32).
e48_value(3.48).
e48_value(3.65).
e48_value(3.83).
e48_value(4.02).
e48_value(4.22).
e48_value(4.42).
e48_value(4.64).
e48_value(4.87).
e48_value(5.11).
e48_value(5.36).
e48_value(5.62).
e48_value(5.90).
e48_value(6.19).
e48_value(6.49).
e48_value(6.81).
e48_value(7.15).
e48_value(7.50).
e48_value(7.87).
e48_value(8.25).
e48_value(8.66).
e48_value(9.09).
e48_value(9.53).

e48_resistor(R):-e48_value(R).
e48_resistor(Y):-e48_value(X),Y is X*10.0.
e48_resistor(Y):-e48_value(X),Y is X*100.0.
e48_resistor(Y):-e48_value(X),Y is X*1000.0.
e48_resistor(Y):-e48_value(X),Y is X*10000.0.
e48_resistor(Y):-e48_value(X),Y is X*100000.0.
e48_resistor(Y):-e48_value(X),Y is X*1000000.0.

e24_value(1.0).
e24_value(1.1).
e24_value(1.2).
e24_value(1.3).
e24_value(1.5).
e24_value(1.6).
e24_value(1.8).
e24_value(2.0).
e24_value(2.2).
e24_value(2.4).
e24_value(2.7).
e24_value(3.0).
e24_value(3.3).
e24_value(3.6).
e24_value(3.9).
e24_value(4.3).
e24_value(4.7).
e24_value(5.1).
e24_value(5.6).
e24_value(6.2).
e24_value(6.8).
e24_value(7.5).
e24_value(8.2).
e24_value(9.1).

e24_resistor(R):-e24_value(R).
e24_resistor(Y):-e24_value(X),Y is X*10.0.
e24_resistor(Y):-e24_value(X),Y is X*100.0.
e24_resistor(Y):-e24_value(X),Y is X*1000.0.
e24_resistor(Y):-e24_value(X),Y is X*10000.0.
e24_resistor(Y):-e24_value(X),Y is X*100000.0.
e24_resistor(Y):-e24_value(X),Y is X*1000000.0.

e12_value(1.0).
e12_value(1.2).
e12_value(1.5).
e12_value(1.8).
e12_value(2.2).
e12_value(2.7).
e12_value(3.3).
e12_value(3.9).
e12_value(4.7).
e12_value(5.6).
e12_value(6.8).
e12_value(8.2).

e12_resistor(R):-e12_value(R).
e12_resistor(Y):-e12_value(X),Y is X*10.0.
e12_resistor(Y):-e12_value(X),Y is X*100.0.
e12_resistor(Y):-e12_value(X),Y is X*1000.0.
e12_resistor(Y):-e12_value(X),Y is X*10000.0.
e12_resistor(Y):-e12_value(X),Y is X*100000.0.
e12_resistor(Y):-e12_value(X),Y is X*1000000.0.
