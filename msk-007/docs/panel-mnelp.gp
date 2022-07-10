set terminal postscript eps
set output "panel-mnelp.eps"

f(x)=(x*x+4)*(x*x+9)/((x+0.239)*(x*x+0.356*x+0.494084)*(x*x+0.120*x+1.048084))
g(x)=20*log(abs(f(x*sqrt(-1)))/290.875885509015)/log(10)
h(x)=arg(f(x*sqrt(-1)))

set samples 1000

set xrange [0.2:5]
set logscale x

set yrange [-80:10]

unset xtics
unset ytics
unset border

plot g(x) notitle with lines lw 10
