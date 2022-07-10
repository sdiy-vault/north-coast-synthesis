set terminal postscript eps size 2,1.5
set output "ntbode.eps"

set samples 1000

set xlabel "frequency"
set xrange [0.01:100]
set logscale x

unset key

set ylabel "power (dB)"
set yrange [-70:10]

f(x)=20*log(abs(sqrt(1/(1+x*x*x*x))-x*x*sqrt(1/(1+x*x*x*x))))/log(10)

plot f(x)
