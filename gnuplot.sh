#!/bin/bash
#cat /usr/local/fix_stats/simple.graph | /usr/bin/gnuplot
/usr/bin/gnuplot <<-finis
#set terminal postscript eps enhanced
set terminal png nocrop enhanced 12 size 1200,768

set output "/root/DEV/MD_LATENCY/md_fix_db.png"
set encoding koi8r
set xlabel "Time (Epoch)"
set ylabel "Price"

#set xrange [111547:182959]
#set xtics 111547,60000
#set xtics ("0.5" 0.5, "1.2" 1.2, "2.3" 2.3)
#set xdata time
#set timefmt "%S:%M"
#set timefmt "%H:%M:%.6S"
#set xtics auto
#set yrange [141000:144500]
#set ytics 0,50
#set ytics auto
#set style line 1 lt 1 pt 1

set format x "%10.1f"
set timefmt "%.3S"
set grid ytics lt 0
set grid xtics lt 0

set auto y

set style line 1 lt 2 lw 1 pt 5 ps 0.65
set style line 2 lt 1 lw 1 pt 4 ps 0.65
set datafile separator " "
plot "/root/DEV/MD_LATENCY/md_dump.txt" using 2:5 title "MD bst ask  - fix" with lines linestyle 1,"/root/DEV/MD_LATENCY/md_dump.txt"  using 2:6 title "MD bst ask - db" with lines linestyle 2
finis

