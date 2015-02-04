#!/bin/bash
#This script is used for deploying PerfectComp components such as ui-manager-service
#,avh-manager-widgets and vritualhost-service.It can be run seperately with any other
#CI tools.
#Ver. 0.95
#Created by Kent Li, 1/13/2015
NEXUS_IP=192.168.1.199
#detect_latest(){
#	if [ -f build.properties.snapshot ]
#		then	
#			rm -f build.properties.snapshot
#	fi
#	wget --http-user=$NEXUS_UESRNAME --http-passwd=$NEXUS_PASSWORD --no-check-certificate \
#	"https://svn.ecwise.com/build.properties.snapshot.php?u=$NEXUS_USERNAME&p=$NEXUS_PASSWORD" \
#	-O ./build.properties.snapshot
#	sed -i 's/<br\/>/\n/g' build.properties.snapshot
#	latest_version=$(grep $1 build.properties.snapshot |awk 'BEGIN {FS="="}{print $2}')
#	echo "The lastest snapshot version for $1 is $latest_version".
#}

update_hosts(){
	if ! grep -q "nexus.ecwise.com" /etc/hosts
		then
			echo "$NEXUS_IP nexus.ecwise.com" >> /etc/hosts
	fi
}

backup_current(){
	install_path=/usr/local/perfectcomp/$1
	if [ -d $install_path ]
		then
			cd ${install_path%/*}
			tar cf $1.previous.tar.gz $install_path
			
	fi
	
}

rollback(){
	if [ -d $install_path ]
		then 	
			rm -rf $install_path
	fi
	cd ${install_path%/*}
	tar xf $1.previous.tar.gz 
	
}

build_components(){
	comp=$1
	release_home=/release_home/$comp
	install_path=/usr/local/perfectcomp/$comp
	package_version=$2
	echo $LINESEP
	if [[ "$package_version" =~ "SNAP" || "$package_version" =~ "LATEST" ]] 
		then 
			snapshot_or_release='snapshots'
			echo "Now we are deploying a SNAPSHOT version of ${fullname["$1"]}..."
		else
			snapshot_or_release='releases'
			echo "Now we are deploying a RELEASE version of u${fullname["$1"]}..."
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
		echo -n "(1/5)Getting package from nexus..."
		wget --quiet --http-user=$USER --http-password=$PASSWORD \
		--no-check-certificate \
		"https://nexus.ecwise.com/service/local/artifact/maven/redirect?r=${snapshot_or_release}&g=com.c2r.perfectcomp&a=ui-manager-service&v=$package_version&e=jar" \
		--output-document=$comp.jar
		
		if [ ! -s $comp.jar ]
			then 
				echo "			[FAILED]"
				echo "$comp.jar is not a valid file, will try downloading again."
				((err_count++))
			else
				echo "			[OK]"
				break
		fi

		if [[ $err_count -gt 2 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	
	#Download application.properties from svn, the same loop as package.
	echo -n "(2/5)Getting property files from svn..."
	for property_file in application.properties logback.xml
	do 
		err_count=0
		while true
		do
			wget  --quiet --http-user=$USER --http-passwd=$PASSWORD \
			--no-check-certificate \
		https://svn.ecwise.com/svn/perfectComp/perfectcomp-configurations/trunk/Staging/${fullname["$1"]}/$property_file \
			-O $release_home/config/$property_file
	
			if [ ! -s $release_home/config/$property_file ]
				then 
					((err_count++))
				else
					break
			fi
	
			if [[ $err_count -gt 2 ]]
				then 
					echo "			[FAILED]"
					echo "Maximum error count exceeded, please try later."
					exit 1
			fi
		done
	done
	echo "			[OK]"
		

	echo -n "(3/5)Clearing old version components..."
	service pc-$comp stop > /dev/null 2>&1
	if [ -d $install_path ] 
		then 
			rm -rf $install_path
	fi
	mkdir -p $install_path && echo "			[OK]"

	echo -n "(4/5)Copying files to install path..."
		cp -rp * $install_path && echo "			[OK]"

	#Download startup script from svn, the same loop as above.
	err_count=0
	while true
	do 
		echo -n "(5/5)Getting startup script form svn..."
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
				echo "			[FAILED]"
				echo "pc-$comp is not a valid file, \
				will try downloading again."
				((err_count++))
			else
				echo "			[OK]"
				break
		fi

		if [[ $err_count -gt 2 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done

	chmod 755 /etc/init.d/pc-$comp
	chkconfig pc-$comp on
	service pc-$comp start > /dev/null
	echo "${fullname["$1"]} is successfully deployed with version: $package_version"
}

build_avhmanager(){
	comp=avhmanager
	release_home=/release_home/$comp
	install_path=/usr/local/perfectcomp/$comp
	package_version=$1	
	echo $LINESEP
	if [[ "$package_version" =~ "SNAP" || "$package_version" =~ "LATEST" ]] 
		then 
			snapshot_or_release='snapshots'
			echo "Now we are deploying a SNAPSHOT version of avh-manager-widgets..."
		else
			snapshot_or_release='releases'
			echo "Now we are deploying a RELEASE version of avh-manager-widgets..." 
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
		echo -n "(1/5)Getting package from nexus..."
		wget --quiet --http-user=$USER --http-password=$PASSWORD \
		--no-check-certificate \
		"https://nexus.ecwise.com/service/local/artifact/maven/redirect?r=${snapshot_or_release}&g=com.c2r.perfectcomp&a=avh-manager-widgets&v=$package_version&e=zip&c=bin" \
		--output-document=$comp.zip
		
		if [ ! -s $comp.zip ]
			then 
				echo "			[FAILED]"
				echo "$comp.zip is not a valid file, will try downloading again."
				((err_count++))
			else
				echo "			[OK]"
				break
		fi

		if [[ $err_count -gt 2 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	
	#Unzip the zip file ,rename the directory
	unzip -q $comp.zip
	(cd avh-manager-widgets-*
	avh_dir=`pwd`
	cd ..
	mv $avh_dir avhmanager)
	
	#Download application.properties from svn, the same loop as package.
	err_count=0
	while true
	do
		echo -n "(2/5)Getting application.properties from svn..."
		wget  --quiet --http-user=$USER --http-passwd=$PASSWORD \
		--no-check-certificate \
	https://svn.ecwise.com/svn/perfectComp/perfectcomp-configurations/trunk/Staging/avh-manager-widgets/avhmanager.properties \
		-O $release_home/config/avhmanager.properties

		if [ ! -s $release_home/config/avhmanager.properties ]
			then 
				echo "		[FAILED]"
				echo "avhmanager.properties is not a valid file, \
				will try downloading again."
				((err_count++))
			else
				echo "		[OK]"
				break
		fi

		if [[ $err_count -gt 2 ]]
			then 
				echo "Maximum error count exceeded, please try later."
				exit 1
		fi
	done
	
	command -v dos2unix  >/dev/null 2>&1 || { echo >&2 "I require dos2unix but it's not installed. I will now install it."; yum -yq install dos2unix > /dev/null 2>&1; }
	dos2unix -q -o $release_home/config/avhmanager.properties

	echo -n "(3/5)Replacing config values in js and css files..."
	for file in $(find $release_home/avhmanager -type f -iname "*.js" -o -iname "*.css")
	do
   		#echo "Processing file: $file"
   		while read -r line
   		do
   		    [ -z "$line" ] && continue
   		    key=${line%%=*}
   		    val=${line#*=}
   		    escapedval=$(echo $val | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')
   		    sed -i -e 's/${'"${key}"'}/'"${escapedval}"'/g' $file
   		done < $release_home/config/avhmanager.properties
	done && echo "	[OK]"

	echo -n "(4/5)Clearing old version components..."
	if [ -d $install_path ] 
		then 
			rm -rf $install_path
	fi
	mkdir -p $install_path && echo "			[OK]"

	echo -n "(5/5)Copying files to install path..."
		cp -rp ./avhmanager/* $install_path && echo "			[OK]"

	echo "avh-manager-widgets is successfully deployed with version: $package_version"
}
	

declare -A fullname=(["avhmanager"]="avh-manager-widgets" \
["virtualhost"]="virtualhost-service" \ 
["uimanager"]="ui-manager-service" \
["virtualhost-job"]="virtualhost-job")

menu(){
	read -p "Do you want to deploy ${fullname["$1"]}? [Y/n]" answer
	
	case $answer in 
		[^Nn]|"")
			echo "Please specify the version you want to deploy. You can enter the precise release"
			echo "number, such as 1.4.5 or snapshot version like 1.4.5-SNAPSHOT, or just enter \"LATEST\""
			echo "to get the latest SNAPSHOT version."
			while true 
			do
				read -p "Please enter the version you want: " version
				[ -z $version ] && echo -n "Version can not be null. " && continue 
				version=${version^^}
				echo "Start deploying ${fullname["$1"]} with version $version, enter Y to proceed,"
				read -p "N to give up, R to modify the version: [Y/n/r]" choice
				case $choice in 
					[Yy])
						echo $LINESEP
						if [[ $1 == "avhmanager" ]]
							then 
								build_avhmanager $version
							else
								build_components $1 $version 
						fi
						break;;
					[Nn])
						echo "Skipping to the next step..."
						break;;
					[Rr])
						;;
					*)
						echo $LINESEP
						if [[ $1 == "avhmanager" ]]
							then 
								build_avhmanager $version
							else
								build_components $1 $version 
						fi
						break;;
				esac
			done;;
		[Nn])
			echo "Skipping to the next step..."
	esac
}


#Here the script starts
LINESEP="==================================================================================="
URL="https://svn.ecwise.com/svn/perfectComp/perfectcomp-configurations/trunk/Staging/avh-manager-widgets/avhmanager.properties"
clear
echo $LINESEP
echo ""
echo "Hello, we are about to deploy the PerfectComp components from SVN."
read -p "Press Enter to continue[ENTER]" var
echo $LINESEP
echo ""
err_try=0
#Validate the account with curl via SVN
while true
do
	read -p "To execute this script, please enter your domain username: " USER
	read -s -p "Please enter your domain password: " PASSWORD
	echo ""
	echo "Validating your authentication, please wait..."
	STATUS_CODE=`curl -u $USER:$PASSWORD -o /dev/null -s -w %{http_code} $URL`
	if [[ $STATUS_CODE == "200" ]]
		then 
			echo "Your authentication is valid, preparing..."
			break
		else
			echo "Your authentication is not valid, please try again."
			((err_try++))
	fi
	if [ $err_try -gt 2 ]
		then 	
			echo "Maximum error count exceeded, please try later."
			exit 1
	fi
done

echo $LINESEP
echo ""
echo "We provide three options for you to proceed the deployment:"
echo "1.Deploy components step by step[DEFAULT]"
echo "2.Deploy all three components from latest snapshot"
echo "3.Rollback previous version you deployed(Currently not functional)"
read -p "Enter your choice, or just press enter to select the default option[1/2/3]: " decision

case $decision in 
	[^23]|"")
		update_hosts
		menu avhmanager
		menu virtualhost
		menu uimanager
		menu virtualhost-job
		;;
	2)
		update_hosts
		build_avhmanager LATEST
		build_components virtualhost LATEST
		build_components uimanager LATEST
		build_components virtualhost-job LATEST
		;;
	3)
		echo "Currently this option is not functional."
		exit 1
		;;
esac

echo $LINESEP
echo "We've finished deploying the PerfectComp components, cheers!"
exit 0
