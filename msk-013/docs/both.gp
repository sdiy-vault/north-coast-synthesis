set terminal postscript eps
set output "both.eps"

g(x)=10*(x-3.7)
f(x)=(-5*sin(x*pi*3/2)+8*exp(g(x))-8*exp(g(-x)))/(1+exp(g(x))+exp(g(-x)))

set samples 1000

set title "both"

set xlabel "input V"
set xrange [-5:5]

set ylabel "output V"
set yrange [-8:8]

set label "Q4" at -4.5,-7.4 center
set label "Q5" at -3,5.5 center
set label "Q6" at -2.333,-5.5 center
set label "Q7" at -1.667,5.5 center
set label "Q8" at -1,-5.5 center
set label "Q9" at -0.333,5.5 center
set label "Q10" at 0.333,-5.5 center
set label "Q11" at 1,5.5 center
set label "Q12" at 1.667,-5.5 center
set label "Q13" at 2.333,5.5 center
set label "Q14" at 3,-5.5 center
set label "Q15" at 4.5,7.4 center

set xtics 1
set grid

unset key

plot f(x) lw 2
