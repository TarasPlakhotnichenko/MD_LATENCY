#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use threads;
use threads::shared;
use DBI;

my $cond : shared = 0;

my $bst_ask_db : shared;
my $bst_ask_db1 : shared;

my $last : shared;
my $last1 : shared;

my $bst_bid_db : shared;
my $bst_bid_db1 : shared;

my $data_source = q/dbi:ODBC:mssql_18/;
my $user = q/sa/;
my $password = q/Admin2Sql/;

#my $SecCode="US3682872078";
my $SecCode="US80585Y3080";



#---initiate db----vvv
`/usr/bin/rrdtool create /var/www/html/market_data/rrd/md_db_bst_ask.rrd  --step 1 DS:db1:GAUGE:2:0:U  DS:db:GAUGE:2:0:U RRA:LAST:0.5:1:600`;

`/usr/bin/rrdtool create /var/www/html/market_data/rrd/md_db_bst_bid.rrd  --step 1 DS:db1:GAUGE:2:0:U  DS:db:GAUGE:2:0:U RRA:LAST:0.5:1:600`;
#---initiate db----^^^


#---MS DB Flow Sync-------------------------------------------------------------------------vvv
my $srv_db_flow_sync = threads->new(\&db_flow_sync,$data_source,$user,$password);

sub db_flow_sync {
my ($data_source,$user,$password) = @_;
my $dbh = DBI->connect($data_source, $user, $password);
my $Class="LSE_MDIOB";
my $tbl="73";


#--- exec [dbo].[ReturnBidOffer] 'US80585Y3080','LSE_MDIOB', 73
my $sth = $dbh->prepare("declare \@SecCode NVARCHAR(100),\@Class NVARCHAR(100) EXEC  dbo.ReturnBidOffer  \@SecCode=$SecCode,\@Class=$Class,\@tbl=$tbl");

while(1) 
 {  
  {lock($cond); cond_wait($cond) until $cond == 1}
    
  $sth->execute(); 
  my $data = $sth->fetchrow_arrayref;
  
  if ($#$data > 0) {
  #print join (',',@$data) . "\n";
  $bst_bid_db = @$data[2];
  $bst_ask_db = @$data[3];
  $last = @$data[4];
  }
  
  #my $time = `date`;
  #chomp ($time);
  #print "syncing time  db: $time\n";
  
  $cond=0;
 }
}
#---MS DB Flow Sync-------------------------------------------------------------------------^^^


#---MS DB Flow Sync 1-----------------------------------------------------------------------vvv
my $srv_db_flow_sync1 = threads->new(\&db_flow_sync1,$data_source,$user,$password);

sub db_flow_sync1 {
my ($data_source,$user,$password) = @_;
my $dbh = DBI->connect($data_source, $user, $password);
my $Class="LSE_IOB";
my $tbl="73";


#--- exec [dbo].[ReturnBidOffer] 'US80585Y3080','LSE_IOB', 73
my $sth = $dbh->prepare("declare \@SecCode NVARCHAR(100),\@Class NVARCHAR(100) EXEC  dbo.ReturnBidOffer  \@SecCode=$SecCode,\@Class=$Class,\@tbl=$tbl");

while(1) 
 {  
  {lock($cond); cond_wait($cond) until $cond == 1}
    
  $sth->execute(); 
  my $data = $sth->fetchrow_arrayref;
  
  if ($#$data > 0) {
  #print join (',',@$data) . "\n";
  $bst_bid_db1 = @$data[2];
  $bst_ask_db1 = @$data[3];
  $last1 = @$data[4];
  }
  
  #my $time = `date`;
  #chomp ($time);
  #print "syncing time  db: $time\n";
  
  $cond=0;
 }
}
#---MS DB Flow Sync 1-----------------------------------------------------------------------^^^



#---Plot------------------------------------------------------------------------------------vvv
my $srv_graph = threads->new(\&graph);

sub graph {
sleep 4;

while(1) {
sleep 10;

if (($bst_ask_db1) and ($bst_bid_db1))
{
my $up_bst_ask_db1 = $bst_ask_db1+0.1;
my $down_bst_ask_db1 = $bst_ask_db1-0.1;
if ($down_bst_ask_db1 < 0)
 {
  $down_bst_ask_db1 = $bst_ask_db1;
 }
 
my $up_bst_bid_db1 = $bst_bid_db1+0.1;
my $down_bst_bid_db1 = $bst_bid_db1-0.1;
if ($down_bst_bid_db1 < 0)
 {
  $down_bst_bid_db1 = $bst_bid_db1;
 }
 

my $END=`date +%s`;
my $START=$END-300; 

my $graph =`/usr/bin/rrdtool graph /var/www/html/market_data/rrd/md_db_bst_ask.gif  -w 600 -h 150  --alt-autoscale    --alt-y-grid   --vertical-label "Price"  -t "MD BEST ASK $SecCode - LSE_IOB vs LSE_MDIOB (grid lines every 2 seconds)" -s "$START" -e now --x-grid  SECOND:2:MINUTE:1:MINUTE:1:0:%X --watermark http://net.open.ru DEF:db1=/var/www/html/market_data/rrd/md_db_bst_ask.rrd:db1:LAST  LINE1:db1#FF0000:"LSE_IOB DB"  DEF:db=/var/www/html/market_data/rrd/md_db_bst_ask.rrd:db:LAST  LINE1:db#164206:"LSE_MDIOB DB" COMMENT:"best ask price LSE_IOB/LSE_MDIOB - $bst_ask_db1/$bst_ask_db"`;
#print "$graph";

$graph =`/usr/bin/rrdtool graph /var/www/html/market_data/rrd/md_db_bst_bid.gif  -w 600 -h 150   --alt-autoscale    --alt-y-grid   --vertical-label "Price"  -t "MD BEST BID $SecCode - LSE_IOB vs LSE_MDIOB (grid lines every 2 seconds)" -s "$START" -e now --x-grid  SECOND:2:MINUTE:1:MINUTE:1:0:%X --watermark http://net.open.ru DEF:db1=/var/www/html/market_data/rrd/md_db_bst_bid.rrd:db1:LAST  LINE1:db1#FF0000:"LSE_IOB DB"  DEF:db=/var/www/html/market_data/rrd/md_db_bst_bid.rrd:db:LAST  LINE1:db#164206:"LSE_MDIOB DB" COMMENT:"best bid price LSE_IOB/LSE_MDIOB - $bst_bid_db1/$bst_bid_db"`;
#print "$graph";
}
}
}
#---Plot------------------------------------------------------------------------------------^^^


#---Main------------------------------------------------------------------------------------vvv

sleep 2;
$cond = 1;
{ no warnings 'threads'; cond_broadcast($cond); }
sleep 2;


while(1)
{
sleep 1;
#select(undef,undef,undef, .5);

$cond = 1;
{ no warnings 'threads'; cond_broadcast($cond); }

my $time = `date '+%y/%m/%d %H:%M:%S'`;
chomp($time);


if (($bst_ask_db1) and ($bst_ask_db))
{
my $update=`/usr/bin/rrdtool updatev  /var/www/html/market_data/rrd/md_db_bst_ask.rrd   N:$bst_ask_db1:$bst_ask_db`;
}

if (($bst_bid_db1) and ($bst_bid_db))
{
my $update=`/usr/bin/rrdtool updatev  /var/www/html/market_data/rrd/md_db_bst_bid.rrd   N:$bst_bid_db1:$bst_bid_db`;
}

#print "$time: best ask LSE_IOB/LSE_MDIOB: $bst_ask_db1 $bst_ask_db,  best bid LSE_IOB/LSE_MDIOB: $bst_bid_db1 $bst_bid_db\n";
print "$time $SecCode best ask LSE_IOB/other provider: $bst_ask_db1 $bst_ask_db,  best bid LSE_IOB/other provider: $bst_bid_db1 $bst_bid_db, last price LSE_IOB/other provider: $last1 $last \n";

}
#---Main------------------------------------------------------------------------------------^^^



   
   
