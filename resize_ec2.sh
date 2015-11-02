#!/bin/bash
# if you specific a root EBS volume that is bigger than 10G, you will need this script to resize the root volume after it boots up.


# Test for a reboot, if this is a reboot just skip this script.
if test "$RS_REBOOT" = "true" ; then
  echo "This is a reboot"
  exit;
fi

yum install -y expect -q
START=`fdisk -u -l /dev/xvda |tail -n 1|awk '{print $3}'`
echo "Starting point is $START"

expect <<- DONE
        spawn fdisk -u /dev/xvda
        expect "*m for help):"
        send "d\r"
        expect "*m for help):"
        send "n\r"
        send "p\r"
        expect "*(1-4):"
        send "1\r"
        expect "*default*"
        send "$START\r"
        expect "*default*"
        send "\r"
        expect "*m for help):"
        send "a\r"
        expect "*(1-4):"
        send "1\r"
        expect "*m for help):"
        send "w\r"
        expect eof
DONE

echo "resize2fs /dev/xvda1" >> /etc/rc.local

# we need to use rs_shutdown --reboot instead of just reboot, otherwise we might lost monitoring data for 8 hours
rs_shutdown --reboot
