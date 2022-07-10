set terminal postscript eps
set output "shaper-combined.eps"

g(x)=10*(x-3.7)
f(x)=(-5*sin(x*pi*3/2)+8*exp(g(x))-8*exp(g(-x)))/(1+exp(g(x))+exp(g(-x)))
p(x)=(-5*sin(x*pi*3/4+pi*5/4)-8*exp(g(-x)))/(1+exp(g(x+0.3))+exp(g(-x)))
q(x)=(-5*sin(x*pi*3/4+pi*3/4)+8*exp(g(x)))/(1+exp(g(x))+exp(g(-x+0.3)))

set samples 1000

set title "sine shaper response curves"

set xlabel "mixed input V"
set xrange [-5:5]

set ylabel "output V"
set yrange [-8:8]

set key top left

set xtics 1
set grid

plot f(x) title "both" lt 1 lw 2, \
  p(x) title "sin" lt 3 lw 2, \
  q(x) title "cos" lt 4 lw 2
