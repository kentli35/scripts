#!/usr/bin/perl -w
#This script is a simple denyhost perl script.
use 5.010;
open LOGFILE,"/var/log/auth.log" or die "Could not open auth.log: $!";
open EXIST,"</etc/hosts.deny" or die "Could not open file: $!";
@hosts=<EXIST>;
open HOSTS,">>/etc/hosts.deny" or die "Could not open file: $!";
my @failed=grep /Failed/, <LOGFILE>;
foreach(@failed){
    my $ip=(split)[-4];
    $count{$ip}++;
}

foreach (keys %count){
    push @list,$_ if $count{$_} > 20 and not /$_/ ~~ @hosts;
}

print HOSTS "sshd:$_\n" foreach @list;
