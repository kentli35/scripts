#!/bin/bash

service logstash stop

#Install java first
yum install -y java-1.7.0-openjdk

#Then Logstash 
rpm -Uvh https://download.elasticsearch.org/logstash/logstash/packages/centos/logstash-1.4.2-1_2c0f5a1.noarch.rpm

echo "input {
file {
type => \"web-log\"
path => \"/mnt/ephemeral/log/*.log\"
}
}
output {
redis {
host => \"$LOGSTASH_SERVER\"
data_type =>\"list\"
key => \"logstash\"
}
}" > /etc/logstash/conf.d/shipper.conf

#Change nginx settings
if ! grep '$hostname' /usr/local/nginx1.4.2/conf/nginx.conf
  then 
    sed -i.bak 's/\$remote_addr -/\$remote_addr \$hostname/' /usr/local/nginx1.4.2/conf/nginx.conf
fi

if ! grep '$request_time' /usr/local/nginx1.4.2/conf/nginx.conf
  then 
    sed -i.bak 's/\$body_bytes_sent/\$body_bytes_sent \$request_time/' /usr/local/nginx1.4.2/conf/nginx.conf
fi

for conf in /etc/nginx/conf.d/*.conf
do
  if ! grep '/cln_nginx_access.log main;' $conf
    then
      sed -i.bak '/cln_nginx_access\.log/ s/\;/ main;/' $conf
  fi
done

service nginx restart
service logstash start

exit 0
