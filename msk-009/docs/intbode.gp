set terminal postscript eps size 2,1.5
set output "intbode.eps"

set samples 1000

set xlabel "frequency"
set xrange [0.01:100]
set logscale x

unset key

set ylabel "power (dB)"
set yrange [-40:40]

f(x)=20*log(1/x)/log(10)

plot f(x)