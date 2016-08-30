#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use threads;
use threads::shared;
use Time::HiRes qw(time);

=comment
IP=192.168.215.70
IP_port = 13055
senderCompID= TCI
targetCompID= SCI

IP=10.230.48.44
IP_port = 9305
senderCompID= TCI
targetCompID=SCI
=cut

my $cond : shared = 0;
my $bst_ask_fix : shared = 0;
my $bst_ask_fix1 : shared = 0;

my $bst_bid_fix : shared = 0;
my $bst_bid_fix1 : shared = 0;

my $str_fix : shared = '';
my $str_fix1 : shared = '';

my $host_fix='192.168.215.70';
my $port_fix='13055';

my $host_fix1='10.230.48.44';
my $port_fix1='9305';



#my $host_fix1='192.168.215.70';
#my $port_fix1='13054';

my $instr='GAZP';


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


#---FIX Flow--------------------------------------------------------------------------------vvv
my $srv_fix_flow = threads->new(\&fix_flow,$host_fix,$port_fix,$instr);

sub fix_flow {
my ($host,$port,$instr) = @_;

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
#print "Sent:  $fix_printable\n";

$sock->send("$fix_msg");
 
$SIG{'ALRM'} = sub { die 'Timeout' };
alarm(4);
 eval
 {
 sysread($sock,$buffer,1024);
 alarm(0);
 }; 
 
 
#print "Received: ";
#if ($buffer)	   
# {
# print "$buffer\n\n";
# }

#-----35=2: ResendRequest,
#----- 7=1: Message sequence number of first message in range to be resent,
#---- 16=0: Message sequence number of last message in range to be resent
#----------------------------------------------------^^^

	 
#END Loggon-----------------------------------------------------------------------------------------^^^


#-----35=V: MarketDataRequest and 35=0: Heartbeat---------------------------------------------------vvv

$time=`date +%Y%m%d-%H:%M:%S`;
	
#FORTS 264=1: Top of Book, 263=1: Snapshot + Updates (Subscribe), 269=0 and 269=1: 0=bid 1=offer, 267=2: Number of MDEntryType(269), 146=1: number of repeating symbols specified. 

$body = "35=V"."$delimit"."49=TCI"."$delimit"."56=SCI"."$delimit"."52=".$time."$delimit"."266=Y"."$delimit". "34=3"."$delimit"."262=7657653331212"."$delimit"."263=1"."$delimit"."264=1"."$delimit"."265=0"."$delimit" .   "146=1"."$delimit"."55=".$instr."$delimit"."48=".$instr."$delimit"."22=8"."$delimit". "207=MICEX"."$delimit"."15=SUR"."$delimit"."267=2"."$delimit"."269=0"."$delimit"."269=1"."$delimit";

$fix_msg=msg_assemble($body,$delimit); 
$fix_printable = convert_delimer($fix_msg);
print "Sent:  $fix_printable\n";
$sock->send("$fix_msg");

#---heartbeat-----------------------------------------------vvv
my $srv_heartbeat = threads->new(\&heart_beat, $sock,$delimit);
#---heartbeat-----------------------------------------------^^^

#print "MD Flow:\n";
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



#---FIX Flow  Sync 1------------------------------------------------------------------------vvv
my $srv_fix_flow_sync1 = threads->new(\&fix_flow_sync1);

sub fix_flow_sync1 {

my $r269_0=qr/269=0/;
my $r269_1=qr/269=1/;
my $r270=qr/270=*/;

while(1) 
 {
  {lock($cond); cond_wait($cond) until $cond == 1}
#my $rand_number1=int(rand(20)) + 100;
#my $rand_number2=int(rand(20)) + 100;
#$str_fix1="8=FIX.4.2|9=178|35=W|49=SCI|56=TCI|34=52|52=20120820-18:37:35|262=7657653331212|55=RIU2|48=RIU2|22=8|100=FORTS|207=FORTS|15=SUR|268=2|269=0|290=1|270=141175|271=88|269=1|290=1|270=141180|271=28|10=138|";
 
#--------get best ask---vvv 
if ($str_fix1)	   
{
 #my $fix_printable = convert_delimer($str_fix1);
 #print "Recieved:  $fix_printable\n";
 
 my @tags = split(/\x01/,$str_fix1);
 #my @tags = split(/\|/,$str_fix1);
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
	   $bst_bid_fix1 = $value;
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
	   $bst_ask_fix1 = $value;
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
#---FIX Flow  Sync 1------------------------------------------------------------------------^^^


#---FIX Flow 1------------------------------------------------------------------------------vvv
my $srv_fix_flow1 = threads->new(\&fix_flow1,$host_fix1,$port_fix1,$instr);

sub fix_flow1 {
my ($host,$port,$instr) = @_;

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
#print "Sent:  $fix_printable\n";

$sock->send("$fix_msg");
	 
$SIG{'ALRM'} = sub { die 'Timeout' };
alarm(2);
 eval
 {
 sysread($sock,$buffer,1024);
 alarm(0);
 };
 
#print "Received: ";
#if ($buffer)	   
# {
# print "$buffer\n\n";
# }

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
alarm(4);
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

$body = "35=V"."$delimit"."49=TCI"."$delimit"."56=SCI"."$delimit"."52=".$time."$delimit"."266=Y"."$delimit". "34=3"."$delimit"."262=7657653331212"."$delimit"."263=1"."$delimit"."264=1"."$delimit"."265=0"."$delimit" .   "146=1"."$delimit"."55=".$instr."$delimit"."48=".$instr."$delimit"."22=8"."$delimit". "207=MICEX"."$delimit"."15=SUR"."$delimit"."267=2"."$delimit"."269=0"."$delimit"."269=1"."$delimit";

$fix_msg=msg_assemble($body,$delimit); 
$fix_printable = convert_delimer($fix_msg);
print "Sent:  $fix_printable\n";
$sock->send("$fix_msg");

#---heartbeat-----------------------------------------------vvv
my $srv_heartbeat = threads->new(\&heart_beat1, $sock,$delimit);
#---heartbeat-----------------------------------------------^^^

#print "MD Flow:\n";
while($sock) {
sysread($sock,$buffer,1024);
$str_fix1=$buffer;
#print "$buffer\n";
}
exit;
#-----35=V: MarketDataRequest and 35=0: Heartbeat---------------------------------------------------^^^
}


#---Heart beat--------------------------------vvv
sub heart_beat1 {
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
#---FIX Flow 1------------------------------------------------------------------------------^^^






#---Main------------------------------------------------------------------------------------vvv
sleep 2;
$cond = 1;
{ no warnings 'threads'; cond_broadcast($cond); }
sleep 2;


while(1)
{


#Sleep time
#sleep 1;
select(undef,undef,undef, .01);



$cond = 1;
{ no warnings 'threads'; cond_broadcast($cond); }

#my ($seconds,$microseconds) = gettimeofday;
my ($seconds) = time;
my $seconds_3f = sprintf("%.3f", $seconds);

#my $sec = sprintf("%.*s", 3, $micro);
#my ($sec, $min) = (localtime($seconds))[0,1]; 

#unless ($bst_ask_fix or $bst_ask_fix1)  {$bst_ask_fix=0; $bst_ask_fix1=0};
#unless ($bst_bid_fix or $bst_bid_fix1) {$bst_bid_fix=0; $bst_bid_fix1=0};

print "epoch: $seconds_3f best_ask fix/fix1: $bst_ask_fix $bst_ask_fix1  best_bid fix/fix1: $bst_bid_fix $bst_bid_fix1\n";

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

   
   
