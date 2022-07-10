set terminal postscript eps
set output "mnelp-bode.eps"

f(x)=(x*x+4)*(x*x+9)/((x+0.239)*(x*x+0.356*x+0.494084)*(x*x+0.120*x+1.048084))
g(x)=20*log(abs(f(x*sqrt(-1)))/290.875885509015)/log(10)
h(x)=arg(f(x*sqrt(-1)))

set samples 1000

set xlabel "normalized frequency"
set xrange [0.1:10]
set logscale x

set ylabel "magnitude (dB, 0 at DC)"
set yrange [-80:10]

set label "(0.356,-2.284)" at 0.3562,-2.2835 \
  point ps 1 offset -8,-1
set label "(0.666,0.001)" at 0.6655,0.0015 \
  point ps 1 offset -8,1
set label "(0.873,-1.824)" at 0.8731,-1.8241 \
  point ps 1 offset -8,-1
set label "(1.000,0.030)" at 1.0003,0.0301 \
  point ps 1 offset -3,1

set label "(2.289,-69.262)" at 2.2894,-69.2618 \
  point ps 1 offset -2,1
set label "(5.506,-67.956)" at 5.5059,-67.9561 \
  point ps 1 offset -3,1

set label "min slope here, 61dB/oct" at 1.414,-33.1949 \
  point ps 1 offset 1,0
  
set y2range [-180:180]
set y2label "phase (degrees)"
set y2tics 40

set label "oscillation f=0.7300" at 0.7300,-35 \
  point ps 1 offset -16,0.5

plot g(x) title "magnitude","helper1.dat" with lines notitle, \
  h(x)*180/pi axes x1y2 title "phase"
