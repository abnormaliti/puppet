#! /bin/bash

# $Id: virtualbox_create_template.sh 6338 2011-02-10 06:18:55Z $

name=vboxtemplate-i386
memory=500
harddisk=80000
port=3389

# --- nothing to edit below this line.

user=vbox
base="/VirtualMachines"
conf="${base}/${name}"
hdd="${conf}/${name}.vdi"

nic="Am79C970A"

SU="su ${user} -c"
VBOXMANAGE="VBoxManage --nologo"

# --- create base VM
$SU "$VBOXMANAGE createvm --name "${name}" --ostype "RedHat" --register --basefolder ${base}"

# --- create the hard disk image.
$SU "$VBOXMANAGE createhd --filename "${hdd}" --size ${harddisk} --format VDI --variant Standard"

# --- config sata, attach harddisk image.
$SU "$VBOXMANAGE modifyvm "${name}" --sata on --sataportcount 4 --sataport1 "${hdd}""

# --- config memory, turn on acpi.
$SU "$VBOXMANAGE modifyvm "${name}" --memory "${memory} MB" --acpi on"

# --- config network
$SU "$VBOXMANAGE modifyvm "${name}" --vrdeport ${port} --cableconnected1 on --nic1 bridged --nictype1 ${nic} --bridgeadapter1 eth0"

# --- second nic
#$SU "$VBOXMANAGE modifyvm "${name}" --cableconnected2 on --nic2 bridged --nictype2 ${nic} --bridgeadapter2 eth1"

# --- third nic
#$SU "$VBOXMANAGE modifyvm "${name}" --cableconnected3 on --nic3 bridged --nictype3 ${nic} --bridgeadapter3 eth2"

# --- config to boot harddisk first then network, this way PXE install starts on first boot then harddisk from then on.
$SU "$VBOXMANAGE modifyvm "${name}" --boot1 disk --boot2 net"
