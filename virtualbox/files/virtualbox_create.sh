#! /bin/bash

# $Id: virtualbox_create.sh 6318 2011-02-09 23:21:54Z $

# --- delete the following line to enable to script, it confirms u have edited the file.
disabled=1

# --- if a filename is passed on the command line it will be imported to define the vars below.
[ -f "$1" ] && . "$1"

name=${NAME:-CentOS.fqdn.com.au}
memory=${MEMORY:-1500}
port=${PORT:-3389}

# --- networking
enable_nic2=${ENABLE_NIC2:-0}
enable_nic3=${ENABLE_NIC3:-0}

bridge_nic2=${BRIDGE_NIC2:-eth1}
bridge_nic3=${BRIDGE_NIC3:-eth2}

# --- CentOS i386
ostype=${OSTYPE:-"RedHat"}
hddtemplatename=${HDDTEMPLATENAME:-"vboxtemplate-i386.vdi.gz"}

# --- CentOS x86_64, uncomment to enable
#ostype=${OSTYPE:-"RedHat_64"}
#hddtemplatename=${HDDTEMPLATENAME:-"vboxtemplate-x86_64.vdi.gz"}

base=${BASE:-"/VirtualMachines"}

# --- 2nd HDD
hdd2=${HDD2:-''}
hdd2size=${HDD2SIZE:-80000}
hdd2file=${HDD2FILE:-"${base}/${hdd2}"}

user=vbox
conf="${base}/${name}"

hddtemplate="rsync://repo.example.com/linux/virtualbox/templates/${hddtemplatename}"
hdd="${conf}/${name}.vdi"

nic="Am79C970A"

SU="su ${user} -c"
VBOXMANAGE="VBoxManage --nologo"

if [ "$disabled" -gt 0 ]; then
  echo "ERROR: You need to edit this script or provide a config file before running it."
  exit 1
fi

if [ ! -d ${base} ]; then
  echo "ERROR: ${base} does not exist."
  exit 1
fi

TMPLOG=$(mktemp /tmp/virtualbox_create.XXXXXXXXX)

echo "BUILD: creating VM" | tee -a ${TMPLOG}
# --- create base VM
$SU "$VBOXMANAGE createvm --name "${name}" --ostype ${ostype} --register --basefolder ${base}"

echo "BUILD: getting HDD template" | tee -a ${TMPLOG}
# --- get hdd template
$SU "/usr/bin/rsync ${hddtemplate} ${base}/"

echo "BUILD: uncompressing HDD template" | tee -a ${TMPLOG}
$SU "gunzip -c ${base}/$(basename ${hddtemplate}) > ${hdd}"

# --- change the UUID for the disk.
$SU "$VBOXMANAGE internalcommands sethduuid ${hdd}"

# --- remove template disk.
$SU "rm -f ${base}/$(basename ${hddtemplate})"

echo "BUILD: configuring VM" | tee -a ${TMPLOG}
# --- config sata, attach harddisk image.
$SU "$VBOXMANAGE modifyvm "${name}" --sata on --sataportcount 4 --sataport1 "${hdd}""

if [ "$hdd2" != '' ]; then
  $SU "$VBOXMANAGE createhd --filename "${hdd2file}" --size ${hdd2size} --format VDI --variant Standard"
  $SU "$VBOXMANAGE modifyvm "${name}" --sataport2 "${hdd2file}""
fi

# --- config memory, turn on acpi.
$SU "$VBOXMANAGE modifyvm "${name}" --memory "${memory} MB" --acpi on"

# --- config network
$SU "$VBOXMANAGE modifyvm "${name}" --vrdeport ${port} --cableconnected1 on --nic1 bridged --nictype1 ${nic} --bridgeadapter1 eth0"

# --- second nic
[ "${enable_nic2}" -gt 0 ] && $SU "$VBOXMANAGE modifyvm "${name}" --cableconnected2 on --nic2 bridged --nictype2 ${nic} --bridgeadapter2 ${bridge_nic2}"

# --- third nic
[ "${enable_nic3}" -gt 0 ] && $SU "$VBOXMANAGE modifyvm "${name}" --cableconnected3 on --nic3 bridged --nictype3 ${nic} --bridgeadapter3 ${bridge_nic3}"

# --- config to boot harddisk first then network, this way PXE install starts on first boot then harddisk from then on.
$SU "$VBOXMANAGE modifyvm "${name}" --boot1 disk --boot2 net"

$SU "$VBOXMANAGE guestproperty set ${name} /CP/hostname ${name}"
$SU "$VBOXMANAGE guestproperty set ${name} /CP/build yes"
$SU "$VBOXMANAGE guestproperty set ${name} /CP/status booting"

echo "BUILD: starting VM" | tee -a ${TMPLOG}
$SU "$VBOXMANAGE startvm ${name} --type headless"

sleep 5

# --- function
getValue ()
{
  prop=$1
  
  result=$( $SU "${VBOXMANAGE} guestproperty get ${name} ${prop}" )
  if [ "$?" -gt "0" ]
  then
    echo unknown
    return 1
  fi
  
  echo "${result}" | sed "s/^Value: //"
  return 0  
}

while [ 1 ]
do
  val=`getValue /CP/status`
  echo -en "BUILD STATUS: ${val}\r"
  echo "BUILD STATUS: ${val}" >> ${TMPLOG}
  [ "$val" = "done" ] && break
  sleep 3
done

echo

ip=`getValue /VirtualBox/GuestInfo/Net/0/V4/IP`

echo "BUILD: VM IP address: ${ip}" | tee -a ${TMPLOG}

echo "BUILD: Complete." | tee -a ${TMPLOG}
