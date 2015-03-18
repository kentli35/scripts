#!/usr/bin/perl -w

if ( -e "/usr/sbin/sendmail" and -e "/usr/sbin/sendmail.postfix"){
    unlink "/usr/sbin/sendmail";
    symlink "/usr/sbin/sendmail.postfix","/usr/sbin/sendmail";
}

my @updateinfo=`yum list-sec`;
my $count=0;
my @report=("Here's the available packages:\n");
foreach (@updateinfo){
    if ($_ ~~ /security/ and not ~~ /plugins/){
        my $package=(split)[2];
        push @report,$package."\n";
        $count ++;
    }
}

if(@report ~~ /ssmtp/){
  @ssmtp=("ssmtp update info:\n");
  push @ssmtp,`rpm -Uvh ftp://fr2.rpmfind.net/linux/epel/6/x86_64/ssmtp-2.61-21.el6.x86_64.rpm`;
  }

if(@report ~~/libyaml/){
  @libyaml=("libyaml update info:\n");
  push @libyaml, `rpm -Uvh ftp://ftp.sunet.se/pub/Linux/distributions/fedora/epel/6/x86_64/libyaml-0.1.6-1.el6.x86_64.rpm`;
  }
  
push @report,"\n";


if($count){
    push @report, "There are $count update(s) in your system.\n";
    push @report, "Proceed automated update:\n:";
    push @report, @ssmtp;
    push @report, @libyaml;
}else{
    @report=();
    push @report, "There's no update available yet.\n";
}

open MAIL,"| mail -s 'Security updates report' hli\@ecwise.com"
    or die "Could not open mail handle:$!\n";

print MAIL foreach @report;
