#!/bin/bash
#Add startup script for CAMP-PROD servers.
#Created by Kent Li, 12/22/2014

test  -e /etc/profile.d/java.sh  \
	|| cat <<< 'export JAVA_HOME=/usr/java/jdk1.7.0_60
PATH=$JAVA_HOME/bin:$PATH
CLASSPATH=.:$JAVA_HOME/lib/tools.jar
export JAVA_HOME CLASSPATH PATH ' > /etc/profile.d/java.sh

detect_activemq(){
( if cd /usr/local/*activemq* 
	then
		echo "Apache activemq detected...generating startup script..."
		activemq_dir=`pwd`

		cat <<< "#!/bin/bash
# description: Tomcat Start Stop Restart
# processname: tomcat
# chkconfig: 234 20 80
#ulimit -Hn 4096
#ulimit -Sn 4096

. /etc/profile.d/java.sh
CATALINA_HOME=$activemq_dir

case \$1 in
start)
cd \$CATALINA_HOME/bin
./activemq start
;;
stop)
cd \$CATALINA_HOME/bin
./activemq stop
;;
restart)
cd \$CATALINA_HOME/bin
./activemq stop
./activemq start
;;

esac
exit 0  " > /etc/init.d/activemq

	chmod +x /etc/init.d/activemq
	chkconfig activemq --add
	
fi )
}

detect_liferay(){
if [ -d /usr/local/liferay ]
	then 
		echo "liferay detected...generating startup script..."
		cat <<< '#!/bin/bash
# description: Tomcat Start Stop Restart
# processname: tomcat
# chkconfig: 234 20 80
ulimit -Hn 4096
ulimit -Sn 4096

. /etc/profile.d/java.sh
CATALINA_HOME=/usr/local/liferay/tomcat-7.0.23

case $1 in
start)
cd $CATALINA_HOME/bin
sh ./startup.sh
;;
stop)
sh $CATALINA_HOME/bin/shutdown.sh
;;
restart)
cd $CATALINA_HOME/bin
sh ./shutdown.sh
sh ./startup.sh
;;
esac
exit 0 ' > /etc/init.d/liferay
		chmod +x /etc/init.d/liferay
		chkconfig liferay --add
fi
}

detect_jboss(){
if [ -d /usr/local/jboss ]
	then 
		echo "jboss detected...generating startup script..."
		cat <<< 'export JBOSS_HOME=/usr/local/jboss
export PATH=$JBOSS_HOME/bin:$PATH ' > /etc/profile.d/jboss.sh
		
		cat <<< '#!/bin/bash
#
# JBoss Control Script
#
# chkconfig: 345 99 20
# description: JBoss Startup File
#
#
# To use this script run it as root - it will switch to the specified user
#
### BEGIN INIT INFO
# Provides:          jboss
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/Stop JBoss AS v7.0.0
### END INIT INFO
#
#source some script files in order to set and export environmental variables
#as well as add the appropriate executables to $PATH
[ -r /etc/profile.d/java.sh ] && . /etc/profile.d/java.sh
[ -r /etc/profile.d/jboss.sh ] && . /etc/profile.d/jboss.sh

PID=`ps -ef | grep java | grep Standalone | awk "{print \$2}"`

case "$1" in
    start)
        echo "Starting JBoss AS 7.0.0"
        #original:
        #sudo -u jboss sh ${JBOSS_HOME}/bin/standalone.sh

        #updated:
        #start-stop-daemon --start --quiet --background --chuid jboss --exec ${JBOSS_HOME}/bin/standalone.sh
        nohup ${JBOSS_HOME}/bin/standalone.sh > ${JBOSS_HOME}/standalone/log/amp-console-output.log 2>&1 &
    ;;
    stop)
        echo "Stopping JBoss AS 7.0.0"
        #original:
        #sudo -u jboss sh ${JBOSS_HOME}/bin/jboss-admin.sh --connect command=:shutdown

        #updated:
        #start-stop-daemon --start --quiet --background --chuid jboss --exec ${JBOSS_HOME}/bin/jboss-admin.sh -- --connect command=:shutdown
        kill -9 $PID
    ;;
    restart)
        echo "Restarting JBoss AS 7.0.0"
        kill -9 $PID
        nohup ${JBOSS_HOME}/bin/standalone.sh > ${JBOSS_HOME}/standalone/log/amp-console-output.log 2>&1 &
    ;;
    *)
        echo "Usage: /etc/init.d/jboss {start|stop}"
        exit 1
    ;;
esac

exit 0 ' > /etc/init.d/jboss
		chmod +x /etc/init.d/jboss
		chkconfig jboss --add
fi
}

detect_tomcat(){
if [ -d /usr/local/tomcat ]
	then 
		echo "tomcat detected...generating startup script..."
		cat <<< '#!/bin/bash
# description: Tomcat Start Stop Restart
# processname: tomcat
# chkconfig: 234 20 80
ulimit -Hn 4096
ulimit -Sn 4096

. /etc/profile.d/java.sh
CATALINA_HOME=/usr/local/tomcat

cd $CATALINA_HOME/bin

case $1 in
start)
sh startup.sh
;;
stop)
sh shutdown.sh
;;
restart)
sh shutdown.sh
sh startup.sh
;;
esac
exit 0 ' > /etc/init.d/tomcat
		chmod +x /etc/init.d/tomcat
		chkconfig tomcat --add
fi
}

if [ $# -eq 0 ]
	then 
		echo "Detecting all services..."
		detect_activemq 
		detect_liferay
		detect_jboss
		detect_tomcat
	else 
		echo "Detecting specific services..."
		while [ $1 ]
		do
			detect_$1
			shift
		done
fi
