#!/bin/bash
#created by James Ye 11/4/2014
#Modified by Kent Li 1/29/2015
#Purposes: Deploy PerfectComp avh-manager from Nexus



# Test for a reboot, if this is a reboot just skip this script.
if test "$RS_REBOOT" = "true" ; then
  echo "This is a reboot"
  exit;
fi


echo "NEXUS_IP: $NEXUS_IP"
echo "AVH_MANAGER_VERSION: $AVH_MANAGER_VERSION"

if echo $AVH_MANAGER_VERSION | grep -iq snapshot; then
  snapshot_or_release='snapshots'
else
  snapshot_or_release='releases'
fi

# deal with the case of LATEST-SNAPSHOT
if echo $AVH_MANAGER_VERSION | grep -iq latest; then
  AVH_MANAGER_VERSION='LATEST'
fi

echo "snapshot_or_release: $snapshot_or_release"
avh_manager_zip_file=avh-manager-widgets.zip

# update hosts file with nexus ip if it is not there
if ! grep -q "nexus.ecwise.com" /etc/hosts ; then
  echo "Updating hosts file with nexus ip"
  echo "$NEXUS_IP nexus.ecwise.com" >> /etc/hosts
fi

release_home=/release_home/avhmanager
if [ -d $release_home ]; then rm -rf $release_home; fi;
mkdir -p $release_home
cd $release_home

zip_category=com.c2r.perfectcomp
zip_name=avh-manager-widgets
zip_version=$AVH_MANAGER_VERSION

echo "getting file from Nexus"
wget --no-verbose --http-user=$NEXUS_USERNAME --http-password=$NEXUS_PASSWORD --no-check-certificate "https://nexus.ecwise.com/service/local/artifact/maven/redirect?r=${snapshot_or_release}&g=${zip_category}&a=${zip_name}&v=${zip_version}&e=zip&c=bin" --output-document=${avh_manager_zip_file};

echo "Done wget"

if  [ ! -f $avh_manager_zip_file ] || [ ! -s $avh_manager_zip_file ] ; then
    echo "$avh_manager_zip_file not found! download from Nexus failed"
    exit 1;
else
    echo "done downloading $avh_manager_zip_file";
fi

#if [ -f ${zip_name}-${zip_version} ] ; then rm -rf ${zip_name}-${zip_version} ; fi; # no need to do this since we delete the whole $release_home above

echo "unzip $avh_manager_zip_file"
unzip -q $avh_manager_zip_file

echo "change directory to ${zip_name}-*";
(cd ${zip_name}-*
avh_dir=`pwd`
cd ..
mv $avh_dir avhmanager)


# Get config file from S3 (need to configure jenkins to push config files to S3) and replace variables in *.js and *.css

echo "copy avhmanager.properties from S3 to $release_home "
s3cmd get s3://perfectcomp/configurations/$ENVIRONMENT/avh-manager-widgets/avhmanager.properties $release_home

command -v dos2unix  >/dev/null 2>&1 || { echo >&2 "I require dos2unix but it's not installed. I will now install it."; yum -yq install dos2unix > /dev/null 2>&1; }
dos2unix -q -o $release_home/avhmanager.properties

echo "done with dos2unix"

echo "replace config vlaues in js and css files"

sed -i -e "s/RANDOM/$RANDOM/" -e '$ s/$/\n/' $release_home/avhmanager.properties

for file in $(find $release_home/avhmanager -type f -iname "*.js" -o -iname "*.css")
do
    echo "processing file: $file"
    while read -r line
    do
        [ -z "$line" ] && continue
        key=${line%%=*}
        val=${line#*=}
        escapedval=$(echo $val | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')
        sed -i -e 's/${'"${key}"'}/'"${escapedval}"'/g' $file
    done < $release_home/avhmanager.properties
done

# copy files to s3 (destination example:  s3://perfectcomp/avhmanager/Staging/ )
# URL example: http://perfectcomp.s3.amazonaws.com/avhmanager/Staging/AvhManager.cb.min.js
# File permission is public read
for file in `find $release_home/avhmanager -type f`
do
  dir=`dirname $file`
  remote_dir=${dir##/release*avhmanager}
  if [[ $file =~ .*\.woff2? ]]
    then s3cmd put --force --recursive --acl-public -m application/octet-stream $file s3://perfectcomp/avhmanager/${ENVIRONMENT}$remote_dir/
  else
    s3cmd put --force --recursive --acl-public --guess-mime-type $file s3://perfectcomp/avhmanager/${ENVIRONMENT}$remote_dir/
  fi
done
#s3cmd put --force --recursive --acl-public --guess-mime-type $release_home/${zip_name}-*/* s3:///avhmanager/$ENVIRONMENT/

#UIManagers need widgets files which has been uploaded just now. So we push these files to UIManagers.
# /root/.ssh/perfectcom-staging is the ssh key from RightScale.  We must manually put it there first# 
# we need to update the ips if they change or we have more uimanagers
for uimanager in 10.0.41.217 10.0.41.164 10.0.41.49 10.0.41.162
do
  ssh -i ~/.ssh/perfectcomp-${ENVIRONMENT,,} $uimanager "s3cmd get --force --recursive s3://perfectcomp/avhmanager/${ENVIRONMENT}/widgets /usr/local/perfectcomp/avhmanager/"
done


echo "done deploying avh manager version $AVH_MANAGER_VERSION to Amazon s3"
