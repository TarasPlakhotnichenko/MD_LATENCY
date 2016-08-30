#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use threads;
use threads::shared;
use DBI;
use Time::HiRes qw(time);

=comment
IP=10.240.16.8
IP_port = 13055
senderCompID= TCI
targetCompID= SCI

IP=10.230.48.44
IP_port = 9305
senderCompID= TCI
targetCompID=SCI
=cut


my $cond : shared = 0;
my $bst_ask_fix : shared;
my $bst_ask_db : shared;

my $bst_bid_fix : shared;
my $bst_bid_db : shared;

my $str_fix : shared = '';

my $data_source = q/dbi:ODBC:mssql_25/;
my $user = q/sa/;
my $password = q/Admin2Sql/;

#my $host_fix='10.240.16.8';
#my $port_fix='13055';

my $host_fix='10.230.48.44';
my $port_fix='9305';

my $SecCode='SBER';


#rrdtool create имя-файла.rrd --start начальное-время --step интервал DS:имя-источника-данных:тип-источника-данных:heartbeat:min:max RRA:функция-консолидации:x-доля:отсчетов-на-ячейку:число-ячеек
#---initiate db----vvv
`/usr/bin/rrdtool create /var/www/html/market_data/rrd/md_fix-db_bst_ask.rrd  --step 1 DS:fix:GAUGE:2:0:U  DS:db:GAUGE:2:0:U RRA:LAST:0.5:1:180`;



`/usr/bin/rrdtool create /var/www/html/market_data/rrd/md_fix-db_bst_bid.rrd  --step 1 DS:fix:GAUGE:2:0:U  DS:db:GAUGE:2:0:U RRA:LAST:0.5:1:180`;
#---initiate db----^^^



#---FIX Flow  Sync--------------------------------------------------------------------------vvv
my $srv_fix_flow_sync = threads->new(\&fix_flow_sync);
sub fix_flow_sync {

my $r269_0=qr/269=0/;
my $r269_1=qr/269=1/;
my $r270=qr/270=*/;

while(1) 
 {
  {lock($cond); cond_wait($cond) until $cond == 1}
#my $rand_number1=int(rand(20)) + 100;
#my $rand_number2=int(rand(20)) + 100;
#$str_fix="8=FIX.4.2|9=178|35=W|49=SCI|56=TCI|34=52|52=20120820-18:37:35|262=7657653331212|55=RIU2|48=RIU2|22=8|100=FORTS|207=FORTS|15=SUR|268=2|269=0|290=1|270=141175|271=88|269=1|290=1|270=141180|271=28|10=138|";
 
#--------get best ask---vvv 
if ($str_fix)	   
{
 #my $fix_printable = convert_delimer($str_fix);
 #print "Recieved:  $fix_printable\n";
 
 my @tags = split(/\x01/,$str_fix);
 #my @tags = split(/\|/,$str_fix);
    my $bid_flag=0;
	my $ask_flag=0;
	my $tags_count = scalar(grep {defined $_} @tags);
	
    for(my $i=0;$i<$tags_count;$i++) {

      #bid---------------vvv
	  if ($tags[$i]=~$r269_0)
	  {
       $bid_flag=1;
	   next;
	  }
      if (($bid_flag==1) and ($tags[$i]=~$r270))
      {
	   my ($key, $value) = split('=',$tags[$i]);
	   $bst_bid_fix = $value;
	   $bid_flag=0;
	   next;
      }
      #bid---------------^^^
	  
	  #ask---------------vvv
	  if ($tags[$i]=~$r269_1)
	  {
      $ask_flag=1;
	  next;
	  }
      if (($ask_flag==1) and ($tags[$i]=~$r270))
      {
	   my ($key, $value) = split('=',$tags[$i]);
	   $bst_ask_fix = $value;
	   $ask_flag=0;
      }
      #ask---------------^^^
    }
}

#--------get best ask---^^^
#my $time = `date`;
#chomp($time);
#print "syncing time fix: $time\n";
$cond=0;

}

}
#---FIX Flow  Sync--------------------------------------------------------------------------^^^


#---MS DB Flow Sync-------------------------------------------------------------------------vvv
my $srv_db_flow_sync = threads->new(\&db_flow_sync,$data_source,$user,$password);

sub db_flow_sync {
my ($data_source,$user,$password) = @_;
my $dbh = DBI->connect($data_source, $user, $password);
#my $SecCode="GAZP";       
my $Class="TQBR";
my $tbl="47";


#use interqort;
#exec [dbo].[ReturnBidOffer] 'SBER','EQBR'
#экспортер на 10.240.16.25
#10.240.16.25: Процедура на БД interqort->Хранимые процедуры->ReturnBidOffer


#--- 41 server:
my $sth = $dbh->prepare("declare \@SecCode NVARCHAR(100),\@Class NVARCHAR(100) EXEC  dbo.ReturnBidOffer  \@SecCode=$SecCode,\@Class=$Class");

#--- 47 server:
#my $sth = $dbh->prepare("declare \@SecCode NVARCHAR(100),\@Class NVARCHAR(100) EXEC  dbo.ReturnBidOffer  \@SecCode=$SecCode,\@Class=$Class,\@tbl=$tbl");

#--- 10.48.16.19 server:
#????

while(1) 
 {  
  {lock($cond); cond_wait($cond) until $cond == 1}
  
#my ($s) = time;

  
  $sth->execute(); 
  my $data = $sth->fetchrow_arrayref;
  if ($#$data > 0) {
  #print join (',',@$data) . "----\n";
  $bst_bid_db = @$data[2];
  $bst_ask_db = @$data[3];
  }
  
  
#my $e = time();
#printf("%.2f\n", $e - $s);  
  
  #$bst_ask_db = 50;
  #$bst_bid_db = 40;
  
  #my $time = `date`;
  #chomp ($time);
  #print "syncing time  db: $time\n";
  
  $cond=0;
 }
}
#---MS DB Flow Sync-------------------------------------------------------------------------^^^


#---FIX Flow--------------------------------------------------------------------------------vvv
my $srv_fix_flow = threads->new(\&fix_flow,$host_fix,$port_fix,$SecCode);

sub fix_flow {
my ($host,$port,$SecCode) = @_;

my $fix_msg="";
my $buffer = '';
my $body="";

my $time=`date +%Y%m%d-%H:%M:%S`;
chomp($time);
my $delimit= chr(1);

my $sock=new IO::Socket::INET->new(PeerPort=>"$port", Proto=>'tcp', PeerAddr=>"$host") or die "Could not create socket: $!\n";



#-----35=A: Logon 141=Y: 141=Y-----------------------vvv

$body = "35=A"."$delimit"."49=TCI"."$delimit"."56=SCI"."$delimit"."34=1"."$delimit"."52=".$time."$delimit"."98=0" ."$delimit"."108=30"."$delimit"."141=Y"."$delimit"; 
$fix_msg=msg_assemble($body,$delimit); 
my $fix_printable = convert_delimer($fix_msg);
print "Sent:  $fix_printable\n";

$sock->send("$fix_msg");
	 
$SIG{'ALRM'} = sub { die 'Timeout' };
alarm(2);
 eval
 {
 sysread($sock,$buffer,1024);
 alarm(0);
 };
 
print "Received: ";
if ($buffer)	   
 {
 print "$buffer\n\n";
 }

#-----35=A: Logon 141=Y: 141=Y-----------------------^^^

	 
#----------------------------------------------------vvv	 
#-----35=2: ResendRequest,
#-----  7=1: Message sequence number of first message in range to be resent,
#---- 16=0: Message sequence number of last message in range to be resent

$body = "35=2"."$delimit"."49=TCI"."$delimit"."56=SCI"."$delimit"."34=2"."$delimit"."52=".$time."$delimit"."7=1"."$delimit"."16=0"."$delimit"; 
$fix_msg=msg_assemble($body,$delimit);
$fix_printable = convert_delimer($fix_msg);
print "Sent:  $fix_printable\n";

$sock->send("$fix_msg");
 
$SIG{'ALRM'} = sub { die 'Timeout' };
alarm(2);
 eval
 {
 sysread($sock,$buffer,1024);
 alarm(0);
 }; 
 
 
print "Received: ";
if ($buffer)	   
 {
 print "$buffer\n\n";
 }

#-----35=2: ResendRequest,
#----- 7=1: Message sequence number of first message in range to be resent,
#---- 16=0: Message sequence number of last message in range to be resent
#----------------------------------------------------^^^

	 
#END Loggon-----------------------------------------------------------------------------------------^^^


#-----35=V: MarketDataRequest and 35=0: Heartbeat---------------------------------------------------vvv

$time=`date +%Y%m%d-%H:%M:%S`;
	
#FORTS 264=1: Top of Book, 263=1: Snapshot + Updates (Subscribe), 269=0 and 269=1: 0=bid 1=offer, 267=2: Number of MDEntryType(269), 146=1: number of repeating symbols specified. 

$body = "35=V"."$delimit"."49=TCI"."$delimit"."56=SCI"."$delimit"."52=".$time."$delimit"."266=Y"."$delimit". "34=3"."$delimit"."262=7657653331212"."$delimit"."263=1"."$delimit"."264=1"."$delimit"."265=0"."$delimit" .   "146=1"."$delimit"."55=".$SecCode."$delimit"."48=".$SecCode."$delimit"."22=8"."$delimit". "207=MICEX"."$delimit"."15=SUR"."$delimit"."267=2"."$delimit"."269=0"."$delimit"."269=1"."$delimit";

$fix_msg=msg_assemble($body,$delimit); 
$fix_printable = convert_delimer($fix_msg);
print "Sent:  $fix_printable\n";
$sock->send("$fix_msg");

#---heartbeat-----------------------------------------------vvv
my $srv_heartbeat = threads->new(\&heart_beat, $sock,$delimit);
#---heartbeat-----------------------------------------------^^^

print "MD Flow:\n";
while($sock) {
sysread($sock,$buffer,1024);
$str_fix=$buffer;
#print "$buffer\n";
}
exit;
#-----35=V: MarketDataRequest and 35=0: Heartbeat---------------------------------------------------^^^
}


#---Heart beat--------------------------------vvv
sub heart_beat {
my ($sock,$delimit) = @_;
my $seqn=4;
while($sock) 
 {
  sleep 30;
  
  my $time=`date +%Y%m%d-%H:%M:%S`;
  chomp($time);
  my $body = "35=0"."$delimit"."49=TCI"."$delimit"."56=SCI"."$delimit"."34=$seqn"."$delimit"."52=4"."$time"."$delimit" ;
  my $fix_msg=msg_assemble($body,$delimit);
  $sock->send("$fix_msg");
  $seqn++;
  
 }
 exit;
}
#---Heart beat--------------------------------^^^
#---FIX Flow--------------------------------------------------------------------------------^^^


#---Plot------------------------------------------------------------------------------------vvv
my $srv_graph = threads->new(\&graph);

sub graph {
sleep 4;

while(1) {
sleep 10;

my $up_bst_ask_fix = $bst_ask_fix+0.5;
my $down_bst_ask_fix = $bst_ask_fix-0.5;
if ($down_bst_ask_fix < 0)
 {
  $down_bst_ask_fix = $bst_ask_fix;
 }
 
my $up_bst_bid_fix = $bst_bid_fix+0.5;
my $down_bst_bid_fix = $bst_bid_fix-0.5;
if ($down_bst_bid_fix < 0)
 {
  $down_bst_bid_fix = $bst_bid_fix;
 } 

my $END=`date +%s`;
my $START=$END-180; 

my $graph =`/usr/bin/rrdtool graph /var/www/html/market_data/rrd/md_fix_db_bst_ask.gif  -w 600 -h 150 -u $up_bst_ask_fix    --alt-autoscale    --alt-y-grid   --vertical-label "Price"  -t "MARKET DATA BEST ASK - fix vs Quik (grid lines every 1 seconds)" -s "$START" -e now --x-grid  SECOND:1:MINUTE:1:MINUTE:1:0:%X --watermark http://net.open.ru DEF:fix=/var/www/html/market_data/rrd/md_fix-db_bst_ask.rrd:fix:LAST:step=1  LINE2:fix#FF0000:"$SecCode FIX"  DEF:db=/var/www/html/market_data/rrd/md_fix-db_bst_ask.rrd:db:LAST:step=1  LINE2:db#164206:"$SecCode DB" COMMENT:"best ask price fix/quik - $bst_ask_fix/$bst_ask_db"`;
#print "$graph";

$graph =`/usr/bin/rrdtool graph /var/www/html/market_data/rrd/md_fix_db_bst_bid.gif  -w 600 -h 150  -u $up_bst_bid_fix  --alt-autoscale    --alt-y-grid   --vertical-label "Price"  -t "MARKET DATA BEST BID - fix vs Quik (grid lines every 1 seconds)" -s "$START" -e now --x-grid  SECOND:1:MINUTE:1:MINUTE:1:0:%X --watermark http://net.open.ru DEF:fix=/var/www/html/market_data/rrd/md_fix-db_bst_bid.rrd:fix:LAST  LINE2:fix#FF0000:"$SecCode FIX"  DEF:db=/var/www/html/market_data/rrd/md_fix-db_bst_bid.rrd:db:LAST  LINE2:db#164206:"$SecCode DB" COMMENT:"best bid price fix/quik - $bst_bid_fix/$bst_bid_db"`;
#print "$graph";
#--x-grid  SECOND:10:MINUTE:3:MINUTE:3:0:%X
#-u $up_bst_ask_fix
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
#sleep 1;
select(undef,undef,undef, .5);
$cond = 1;
{ no warnings 'threads'; cond_broadcast($cond); }

#my $time = `date`;
#chomp($time);

my ($start) = time;
my $seconds_3f = sprintf("%.3f", $start);


if (($bst_ask_fix) or ($bst_ask_db))
{
unless ($bst_ask_fix) {$bst_ask_fix=0};
my $update=`/usr/bin/rrdtool updatev  /var/www/html/market_data/rrd/md_fix-db_bst_ask.rrd   N:$bst_ask_fix:$bst_ask_db`;
}

if (($bst_bid_fix) or ($bst_bid_db))
{
unless ($bst_bid_fix) {$bst_bid_fix=0};
my $update=`/usr/bin/rrdtool updatev  /var/www/html/market_data/rrd/md_fix-db_bst_bid.rrd   N:$bst_bid_fix:$bst_bid_db`;
}

#print "epoch: $seconds_3f best_ask fix/quik: $bst_ask_fix $bst_ask_db  best_bid fix/quik: $bst_bid_fix $bst_bid_db\n";


#my $end = time();
#printf("%.2f\n", $end - $start);

}
#---Main------------------------------------------------------------------------------------^^^

sub msg_assemble
{
  my($body, $delimit) = @_;
  my $body_length=0;
  my $body_plus="";
  my $msg="";
  #Assembling message
  $body_length=length($body);
  $body_plus = "8=FIX.4.2" . $delimit .   "9=" . "$body_length" . $delimit .  "$body";

  #Count checksum
  my $sum=0;
  my $sum256=0;
  for (my $i = 0; $i < length($body_plus); $i++)
    {
    $sum=$sum + ord(substr($body_plus, $i, length($body_plus)));
    }
  #End count CheckSum
  $sum256 = $sum % 256;
  $msg = "$body_plus"    .   "10=" . "$sum256"  . "$delimit";

  return $msg;
#END-Assembling message
}

sub convert_delimer
{
my($buffer) = @_;
my $new_string='';
for (my $i = 0; $i < length($buffer); $i++)
  {
      if (1 == ord(substr($buffer, $i, 1)))
      {
       $new_string=$new_string . "|"; 
      } else
      {
      $new_string=$new_string . substr($buffer, $i, 1);
      }
  }
 return $new_string; 
}

   
   
