#!/bin/bash
#Created by Kent Li, 1/28/2015

# Test for a reboot, if this is a reboot just skip this script.
if test "$RS_REBOOT" = "true" ; then
  echo "This is a reboot, do nothing"
  exit 0;
fi

echo "set open file limit to 102400, default is only 1024";
if ! grep 102400 /etc/security/limits.conf | grep root; then
echo "
root    soft    nofile  102400
root    hard    nofile  102400
" >> /etc/security/limits.conf
else
        echo "found 102400 and root";
fi;

# stop all the services
for services in elasticsearch nginx logstash redis
do 
  service $services stop
done

#Install requesites, jre should be installed by PerfectComp-Install-JRE1.8 which requied by other components
echo "Installing requesites via yum..."
yum install -y -q tcl nginx redis

#changed redis bidning from 127.0.0.1 to 0.0.0.0
sed -i '/^bind/ s!127.0.0.1!0.0.0.0!' /etc/redis.conf

#Download and install logstash binaries
echo "Installing logstash binaries from its website..."
rpm -Uvh ftp://fr2.rpmfind.net/linux/centos/6.6/os/x86_64/Packages/java-1.7.0-openjdk-1.7.0.65-2.5.1.2.el6_5.x86_64.rpm
rpm -Uvh https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.4.2.noarch.rpm
rpm -Uvh https://download.elasticsearch.org/logstash/logstash/packages/centos/logstash-1.4.2-1_2c0f5a1.noarch.rpm

#Download kibana files and exact it to /usr/local
echo "Getting kibana files..."
[ -f kibana-3.1.2.tar.gz ] && rm -f kibana-3.1.2.tar.gz
wget https://download.elasticsearch.org/kibana/kibana/kibana-3.1.2.tar.gz
tar xf kibana-3.1.2.tar.gz -C /usr/local
mv /usr/local/kibana-3.1.2 /usr/local/kibana

#Configurations
echo "Making changes to configuration files..."
sed -i '/location \//,+1s!/usr/share/nginx/html!/usr/local/kibana!' /etc/nginx/conf.d/default.conf 

echo "http.cors.enabled: true
http.cors.allow-origin: \"*\"" >> /etc/elasticsearch/elasticsearch.yml

echo "input {
 redis {
    host => '127.0.0.1'
    key => 'logstash'
    data_type => 'list'
    codec => json
    port => 6379
  }
}


output {
   elasticsearch {
      host => localhost
   }
}" > /etc/logstash/conf.d/logstash.conf

#Set services to start on boot 
echo "Setting services to start on boot..."
chkconfig --add elasticsearch
for services in elasticsearch nginx logstash redis
do 
  chkconfig $services on
  service $services start
done


exit 0
