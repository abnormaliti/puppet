#!/bin/bash

# $Id: virtualbox_client_builder.sh 6342 2011-02-10 22:58:56Z $

VBC="/usr/bin/VBoxControl -nologo"

[ -x /usr/bin/VBoxControl ] || exit 1

getValue ()
{
  prop=$1
  
  result=$( ${VBC} guestproperty get ${prop} )
  if [ "$?" -gt "0" ]
  then
    echo unknown
    return 1
  fi
  
  echo "${result}" | sed "s/^Value: //"
  return 0  
}

setValue ()
{
  prop=$1
  val=$2
  
  ${VBC} guestproperty set ${prop} ${val}
  if [ "$?" -gt "0" ]
  then
    echo ERROR
    return 1
  fi
}

if [ "$( getValue /CP/build )" != "yes" ]
then
  # --- build is done or not required
  exit 0
fi

# --- checking for an update to this script
unalias cp 2>/dev/null

# --- copy this script to temp location, then re-execute self.
if [ "$0" != "/tmp/builder.sh" ]
then
  cp -f $0 /tmp/builder.sh
  chmod +x /tmp/builder.sh
  exec /tmp/builder.sh
fi

# --- prevent svn export twice.
if [ "$1" != "update" ]
then
  rm -f /usr/local/sbin/virtualbox_client_builder.sh
  /usr/bin/rsync --copy-links --inplace rsync://repo.example.com/linux/virtualbox/virtualbox_client_builder.sh /usr/local/sbin/virtualbox_client_builder.sh
fi

# --- if this script has been updated, copy this script to temp location, then re-execute self.
if ! diff -q $0 /usr/local/sbin/virtualbox_client_builder.sh > /dev/null 2>&1
then
  cat /usr/local/sbin/virtualbox_client_builder.sh > $0
  exec /tmp/builder.sh update
fi

hn=$( getValue /CP/hostname )
if [ $? -gt 0 ]
then
  echo "ERROR: Could not get hostname from VBoxControl"
  setValue /CP/build error
  exit 1
fi

# --- set hostname from VBoxControl so puppet knowns
setValue /CP/status setting_hostname
/bin/hostname ${hn}

# --- run puppet to configure the system
setValue /CP/status updating_puppet
yum -y update puppet

setValue /CP/status running_puppet
/etc/init.d/puppet once --test

# --- remove vboxtemplate from the hosts file.
setValue /CP/status cleaning_hosts
sed -i '/vboxtemplate/d' /etc/hosts

# --- run yum to update the system
setValue /CP/status running_yum
ulog=/var/log/upgrade-$(date "+%Y%m%d%H%M").log
yum -y -d1 clean all --enablerepo=\* | tee -a $ulog
yum -y -d1 update glibc\*  | tee -a $ulog
yum -y -d1 update yum\* rpm\* python\*  | tee -a $ulog
yum -y -d1 clean all  | tee -a $ulog
yum -y -d1 update --disablerepo=epel-testing  | tee -a $ulog
rm -fv /etc/yum.repos.d/Cent*.repo | tee -a $ulog
yum -y -d1 clean packages --enablerepo=\* | tee -a $ulog

setValue /CP/status done
setValue /CP/build done

rm -f /tmp/builder.sh
