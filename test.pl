#!/usr/bin/perl -w
use strict;
use warnings;
no strict "refs";
use Time::HiRes qw(time);
my $t0 = time; 

#my @queue = ( ['a', 'b', 'c'],
#            ['d', 'e', 'f'],
#            ['g', 'h', 'i'],
#          );


my @item = ((0) x 5);
my @queue = ([(1) x 5],[(1) x 5],[(1) x 5],[(1) x 5],);


push @queue, ['9', '11', '12', '13', '14'];
push @queue, ['9', '111', '12', '13', '14'];
push @queue, ['9', '1111', '12', '13', '14'];
shift(@queue);





for(my $i=10000;$i>=0;$i--) {
push @queue, ['9', '11', '12', '13', '14'];
  
}


my $elapsed = time - $t0;
printf("%.3f\n", $elapsed);

