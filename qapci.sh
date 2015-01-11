#!/bin/bash
#TEST
USER=SVNDeployment
PASSWORD=ILoveECWise2013!
NEXUS_IP=192.168.1.199

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

#components can be: uimanager,virtualhost,avhmanager
build_components(){
	release_home=/release_home/$1
	install_path=/usr/local/perfectcomp/$1
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
	wget  --quiet --http-user=$NEXUS_UESRNAME --http-passwd=$NEXUS_PASSWORD \
	--no-check-certificate \
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
	wget  --quiet --http-user=$NEXUS_UESRNAME --http-passwd=$NEXUS_PASSWORD \
	--no-check-certificate \
	https://svn.ecwise.com/svn/perfectComp/utility-scripts/service-control/trunk/pc-uimanager \
	-O /etc/init.d/$software
	chmod 755 /etc/init.d/$software
	service $software start

	echo "$software is successfully deployed with version $package_version!"
}

build_uimanager(){
	comp=uimanager
	release_home=/release_home/$comp
	install_path=/usr/local/perfectcomp/$comp
	package_version=$1	
	if [[ "$package_version" =~ "SNAP" || "$package_version" =~ "LATEST" ]] 
		then 
			snapshot_or_release='snapshots'
			echo "You are deploying a SNAPSHOT version of Virtualhost..."
		else
			snapshot_or_release='releases'
			echo "You are deploying a RELEASE version of Virtualhost..." 
	fi

	if [ -d $release_home ]
		then 
			rm -rf $release_home
	fi
	
	mkdir -p $release_home/config && cd $release_home
	
	#Download the package from Nexus, here we use a while loop to check if the
	#package is valid, if not, we'll download it again until the package file 
	#is correct and ready to use.
	err_count=0
	while true
	do
		echo -n "Getting package from nexus..."
		wget --quiet --http-user=$USER --http-password=$PASSWORD \
		--no-check-certificate \
		"https://nexus.ecwise.com/service/local/artifact/maven/redirect?r=${snapshot_or_release}&g=com.c2r.perfectcomp&a=ui-manager-service&v=$package_version&e=jar" \
		--output-document=$comp.jar
		
		if [ ! -s $comp.jar ]
			then 
				echo "[FAILED]"
				echo "$comp.jar is not a valid file, will try downloading again."
				((err_count++))
			else
				echo "[OK]"
				break
		fi

		if [[ $err_count -gt 3 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	
	#Download application.properties from svn, the same loop as package.
	err_count=0
	while true
	do
		echo -n "Getting application.properties from svn..."
		wget  --quiet --http-user=$USER --http-passwd=$PASSWORD \
		--no-check-certificate \
	https://svn.ecwise.com/svn/perfectComp/perfectcomp-configurations/trunk/Staging/ui-manager-service/application.properties \
		-O $release_home/config/application.properties

		if [ ! -s $release_home/config/application.properties ]
			then 
				echo "[FAILED]"
				echo "application.properties is not a valid file, \
				will try downloading again."
				((err_count++))
			else
				echo "[OK]"
				break
		fi

		if [[ $err_count -gt 3 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	

	echo -n "Clearing old version components..."
	service pc-$comp stop > /dev/null
	if [ -d $install_path ] 
		then 
			rm -rf $install_path
	fi
	mkdir -p $install_path && echo "[OK]"

	echo -n "Copying files to install path..."
		cp -rp * $install_path && echo "[OK]"

	#Download startup script from svn, the same loop as above.
	err_count=0
	while true
	do 
		echo -n "Getting startup script form svn..."
		if [ -f /etc/init.d/pc-$comp ] 	
			then
				rm /etc/init.d/pc-$comp
		fi
		wget --quiet --http-user=$USER --http-passwd=$PASSWORD \
		--no-check-certificate \
		https://svn.ecwise.com/svn/perfectComp/utility-scripts/service-control/trunk/pc-$comp \
		-O /etc/init.d/pc-$comp

		if [ ! -s /etc/init.d/pc-$comp ]
			then 
				echo "[FAILED]"
				echo "pc-$comp is not a valid file, \
				will try downloading again."
				((err_count++))
			else
				echo "[OK]"
				break
		fi

		if [[ $err_count -gt 3 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done

	chmod 755 /etc/init.d/pc-$comp
	service pc-$comp start
	echo "UI Manager service is successfully deployed with version: $package_version!"
}

build_virtualhost(){
	comp=virtualhost
	release_home=/release_home/$comp
	install_path=/usr/local/perfectcomp/$comp
	package_version=$1	
	if [[ "$package_version" =~ "SNAP" || "$package_version" =~ "LATEST" ]] 
		then 
			snapshot_or_release='snapshots'
			echo "You are deploying a SNAPSHOT version of UI Manager..."
		else
			snapshot_or_release='releases'
			echo "You are deploying a RELEASE version of UI Manager..." 
	fi

	if [ -d $release_home ]
		then 
			rm -rf $release_home
	fi
	
	mkdir -p $release_home/config && cd $release_home
	
	#Download the package from Nexus, here we use a while loop to check if the
	#package is valid, if not, we'll download it again until the package file 
	#is correct and ready to use.
	err_count=0
	while true
	do
		echo -n "Getting package from nexus..."
		wget --quiet --http-user=$USER --http-password=$PASSWORD \
		--no-check-certificate \
		"https://nexus.ecwise.com/service/local/artifact/maven/redirect?r=${snapshot_or_release}&g=com.c2r.perfectcomp&a=virtualhost-service&v=$package_version&e=jar" \
		--output-document=$comp.jar
		
		if [ ! -s $comp.jar ]
			then 
				echo "[FAILED]"
				echo "$comp.jar is not a valid file, will try downloading again."
				((err_count++))
			else
				echo "[OK]"
				break
		fi

		if [[ $err_count -gt 3 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	
	#Download application.properties from svn, the same loop as package.
	err_count=0
	while true
	do
		echo -n "Getting application.properties from svn..."
		wget  --quiet --http-user=$USER --http-passwd=$PASSWORD \
		--no-check-certificate \
	https://svn.ecwise.com/svn/perfectComp/perfectcomp-configurations/trunk/Staging/virtualhost-service/application.properties \
		-O $release_home/config/application.properties

		if [ ! -s $release_home/config/application.properties ]
			then 
				echo "[FAILED]"
				echo "application.properties is not a valid file, \
				will try downloading again."
				((err_count++))
			else
				echo "[OK]"
				break
		fi

		if [[ $err_count -gt 3 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	

	echo -n "Clearing old version components..."
	service pc-$comp stop > /dev/null
	if [ -d $install_path ] 
		then 
			rm -rf $install_path
	fi
	mkdir -p $install_path && echo "[OK]"

	echo -n "Copying files to install path..."
		cp -rp * $install_path && echo "[OK]"

	#Download startup script from svn, the same loop as above.
	err_count=0
	while true
	do 
		echo -n "Getting startup script form svn..."
		if [ -f /etc/init.d/pc-$comp ] 	
			then
				rm /etc/init.d/pc-$comp
		fi
		wget --quiet --http-user=$USER --http-passwd=$PASSWORD \
		--no-check-certificate \
		https://svn.ecwise.com/svn/perfectComp/utility-scripts/service-control/trunk/pc-$comp \
		-O /etc/init.d/pc-$comp

		if [ ! -s /etc/init.d/pc-$comp ]
			then 
				echo "[FAILED]"
				echo "pc-$comp is not a valid file, \
				will try downloading again."
				((err_count++))
			else
				echo "[OK]"
				break
		fi

		if [[ $err_count -gt 3 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done

	chmod 755 /etc/init.d/pc-$comp
	service pc-$comp start
	echo "Virtualhost service is successfully deployed with version: $package_version!"
}

build_uimanager LATEST
build_virtualhost LATEST
