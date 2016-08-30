#!/usr/bin/perl
use strict;
use warnings;
use threads;
use threads::shared;
my $cond : shared = 0;
my $str_fix : shared = 123;

#---Bridge----------------------------------vvv
my $srv_fix = threads->new(\&bridge);
sub bridge {
while(1) 
 {  
  {lock($cond); cond_wait($cond) until $cond == 1}
  my $time = `date`;
  #sleep 1;
  print "unlocked sub1 $time";
  $cond=0;
  print "$str_fix\n";
 }
}
#---Bridge----------------------------------^^^



#---MS DB-------------------------------------vvv
my $srv_db = threads->new(\&db);

sub db {
while(1) 
 {  
  {lock($cond); cond_wait($cond) until $cond == 1}
  my $time = `date`;
  #sleep 1;
  print "unlocked sub2 $time";
  $cond=0;
  $str_fix++;
 }
}
#---MS DB-------------------------------------^^^

while(1)
{
sleep 5;
$cond = 1;
#{ no warnings 'threads'; cond_broadcast($cond); }
}

