#!/usr/bin/perl -w
use strict;
use warnings;
use DBI;
#use DBD::ODBC;

#$ENV{ODBCINI}='/etc/odbc.ini';
#$ENV{ODBCHOME}='/usr/local/unixodbc';
#$ENV{ODBCSYSINI}='/etc';



# Replace datasource_name with the name of your data source.
# Replace database_username and database_password
# with the SQL Server database username and password.
my $data_source = q/dbi:ODBC:mssql_18/;
my $user = q/sa/;
my $password = q/Admin2Sql/;

# Connect to the data source and get a handle for that connection.
my $dbh = DBI->connect($data_source, $user, $password);

my $SecCode="RIU2";                                                                                                                        
my $Class="SPBFUT";

my $sth = $dbh->prepare("declare \@SecCode NVARCHAR(100),\@Class NVARCHAR(100) EXEC  dbo.ReturnBidOffer  \@SecCode=$SecCode,\@Class=$Class");


$sth->execute(); 
my $data = $sth->fetchrow_arrayref;

if ($#$data > 0) {
#print join(" ", @$data),"n";
print @$data[0] . "\n";
print @$data[1] . "\n";
print @$data[2] . "\n";
print @$data[3] . "\n";
}

$sth->finish;                                                                                                                  
$dbh->disconnect;                                                                                                              
exit(0);              
