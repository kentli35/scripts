#!/bin/bash
#TEST
NEXUS_USERNAME=SVNDeployment
NEXUS_PASSWORD=ILoveECWise2013!
NEXUS_IP=192.168.1.199
software=ui-manager-service


detect_latest(){
	if [ -f build.properties.snapshot ]
		then	
			rm -f build.properties.snapshot
	fi
	wget --http-user=$NEXUS_UESRNAME --http-passwd=$NEXUS_PASSWORD --no-check-certificate \
	"https://svn.ecwise.com/build.properties.snapshot.php?u=$NEXUS_USERNAME&p=$NEXUS_PASSWORD" \
	-O ./build.properties.snapshot
	sed -i 's/<br\/>/\n/g' build.properties.snapshot
	latest_version=$(grep $1 build.properties.snapshot |awk 'BEGIN {FS="="}{print $2}')
	echo "The lastest snapshot version for $1 is $package_version".
}

update_hosts(){
	if ! grep -q "nexus.ecwise.com" /etc/hosts
		then
			echo "Updating hosts file with nexus ip"
			echo "$NEXUS_IP nexus.ecwise.com" >> /etc/hosts
	fi
}

build_components(){
	release_home=/release_home/$1
	install_path=/usr/local/$1
	if [ -d $release_home ]
		then 
			rm -rf $release_home
	fi
	
	mkdir -p $release_home/config && cd $release_home
	
	echo "Getting package from nexus..."
	wget --quiet --http-user=$NEXUS_USERNAME --http-password=$NEXUS_PASSWORD \
	--no-check-certificate \
	"https://nexus.ecwise.com/service/local/artifact/maven/redirect?\
	r=snapshots&g=com.c2r.perfectcomp&a=$software&v=$package_version&e=jar" \
	--output-document=$software.jar
	
	if [ ! -s $software.jar ]
		then 
			echo "$software.jar is not a valid file, downlaod failed."
			exit 1
	fi
	
	echo "Getting application.properties from svn..."
	wget  --http-user=$NEXUS_UESRNAME --http-passwd=$NEXUS_PASSWORD --no-check-certificate \
	https://svn.ecwise.com/svn/perfectComp/perfectcomp-configurations/trunk/QA/$1\
	/application.properties -O $release_home/config/application.properties

	echo "Clearing old version components..."
	service $software stop
	if [ -d $install_path ] 
		then 
			rm -rf $install_path
	fi
	mkdir -p $install_path

	echo "Copying files to install path..."
		cp -rp * $install_path

	echo "Getting startup script form svn..."
	if [ -f /etc/init.d/$software ] 	
		then
			rm $servicefile
	fi
	wget  --http-user=$NEXUS_UESRNAME --http-passwd=$NEXUS_PASSWORD --no-check-certificate \
	https://svn.ecwise.com/svn/perfectComp/utility-scripts/service-control/trunk/pc-uimanager \
	-O /etc/init.d/$software
	chmod 755 /etc/init.d/$software
	service $software start

	echo "$software is successfully deployed with version $package_version!"
}


