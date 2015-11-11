#!/bin/bash
#Install zabbix agent on client servers.
#Ver 1.21 by Kent Li
LOGDIR=/var/log/zabbix-agent
CONFIGDIR=/etc/zabbix
PIDDIR=/var/run/zabbix

if [ $UID -ne 0 ]
    then
        echo "You must be root to run this script,exiting..."
    exit 1
fi

za_re(){
if [ $? -eq 0 ]
    then
        echo "done..."
    else
        echo "failed..."
fi
}

za_install(){
#Add zabbix user to run the agent.
echo -n "Adding zabbix user to the system..."
useradd -M -s /sbin/nologin zabbix
za_re
#Make log directory and chown
echo -n "Creating log directory to $LOGDIR..."
mkdir -p $LOGDIR
za_re
chown zabbix:zabbix $LOGDIR
#Copy the config file to the /etc directory.
echo -n "Copying config files to $CONFIGDIR..."
mkdir $CONFIGDIR
cp -r conf/* $CONFIGDIR
za_re

echo -n "Setting hostname in config file..."
sed -i "s/###HOSTNAME###/${HOSTNAME}/" /etc/zabbix/zabbix_agentd.conf
za_re
#Copy the binary file to /bin and /sbin .
echo -n "Copying binaries to the system..."
cp bin/* /bin && cp sbin/* /sbin
za_re
#Copy startup script to the system.
echo "Making startup script..."
if grep -iq "ubuntu" /etc/issue
    then
        echo "Ubuntu distribution ,let me update-rc.d it..."
        cp zabbix-agent-ubuntu /etc/init.d/zabbix-agent
        update-rc.d zabbix-agent defaults
        za_re
    elif grep -iq "centos" /etc/issue
        then
            echo "Centos distribution ,let me chkconfig it..."
            cp zabbix-agent-centos /etc/init.d/zabbix-agent
            chkconfig zabbix-agent --add && chkconfig zabbix-agent on
            za_re
        else
            echo "This linux is either Ubuntu nor Centos, manage the startup script on your own dude."
    fi
fi
#Test if this works
mkdir -p $PIDDIR
/etc/init.d/zabbix-agent start
sleep 2
if [ -e $PIDDIR/zabbix_agentd.pid ]
    then
        echo "Zabbix is running."
    else
        echo "Something is wrong,please check."
        exit 1
fi
}

za_remove(){
if [ -e $PIDDIR/zabbix_agentd.pid ]
    then
    echo "Zabbix agent is still running ,let me kill it..."
    pkill zabbix_agentd
    if [ $? -eq 0 ]
        then
            echo "Process has been killed,let's move on..."
        else
            echo "Killing failed ,try again dude."
            exit 1
    fi
fi
#Delete zabbix user from the system
echo -n "Deleting zabbix user from the system..."
userdel -r zabbix
za_re

#Remove all the files
echo -n "Deleting binary files..."
rm /bin/zabbix* -f && rm /sbin/zabbix* -f
za_re

echo -n "Deleting startup script..."
if grep -iq "ubuntu" /etc/issue
    then
        update-rc.d zabbix-agent purge
        rm /etc/init.d/zabbix-agent -f
        za_re
    elif grep -iq "centos" /etc/issue
            then
                chkconfig zabbix-agent off && chkconfig zabbix-agent --del
                rm /etc/init.d/zabbix-agent -f
                za_re
            else
                echo "Maybe some other distributions , remove the script manually."
    fi
fi

echo -n "Deleting config files..."
rm $CONFIGDIR -rf
za_re

read -p "Would you like to keep the log files[Y/N]: " ANSWER
case $ANSWER in
    [Yy])
        echo "Log files are kept in $LOGDIR" ;;
    [Nn])
        rm -rf $LOGDIR
        echo "Log files have been deleted..." ;;
esac
echo "Zabbix Agent has been removed."
}
case $1 in
    install)
        za_install ;;
    remove)
        za_remove ;;
    *)
        echo "Usage: `basename $0` install/remove" ;;
esac
exit 0
