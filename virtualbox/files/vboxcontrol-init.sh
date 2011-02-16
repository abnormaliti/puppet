#!/bin/bash

# $Id: vboxcontrol-init.sh 6357 2011-02-15 03:24:34Z $

# chkconfig: 235 98 02
# description: VirtualBox VM service
#
### BEGIN INIT INFO
# Provides:       vboxcontrol
# Required-Start: vboxdrv
# Required-Stop:  vboxdrv
# Default-Start:  2 3 5
# Default-Stop:   0 6
# Description:    VirtualBox VM service
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/sbin

[ -f /etc/sysconfig/vboxcontrol ] && . /etc/sysconfig/vboxcontrol
lockfile=${LOCKFILE:-/var/lock/subsys/vboxcontrol}
pidfile=${PIDFILE:-/var/run/vboxcontrol.pid}
RETVAL=0

# --- VBOX_USER must be defined
[ -z "$VBOX_USER" ] && { echo "ERROR: VBOX_USER must be set in /etc/sysconfig/vboxcontrol"; exit 1; }

SU="su $VBOX_USER -c"
VBOXMANAGE="VBoxManage --nologo"
VBOX_LIST_D=${VBOX_LIST_D:-"/etc/vbox/machines_enabled.d"}
VBOX_BASE=${VBOX_BASE:-"/VirtualMachines"}

# --- maximum loops to wait for all VMs to shutdown, 180 * 5 sec = 15mins
MAX_WAIT=180

# Source function library.
. /etc/rc.d/init.d/functions

vboxdrvrunning() {
    lsmod | grep -q "vboxdrv[^_-]"
}

wait_for_closing_machines() {
  count=0
  while [ ${count} -lt ${MAX_WAIT} ]; do
    RUNNING_MACHINES=`$SU "$VBOXMANAGE list runningvms" | wc -l`
    [ $RUNNING_MACHINES = 0 ] && break
    sleep 5
    count=$((count + 1))
  done
}

start() {
  [ -d "$VBOX_LIST_D" ] || exit 0
  echo -n $"Starting VirtualBox VMs: "
  vboxdrvrunning || {
   failure "VirtualBox kernel module not loaded!"
   exit 0
  }
  success
  [ $RETVAL = 0 ] && touch ${lockfile}
  echo

  for VMFILE in ${VBOX_LIST_D}/* ;do
    [ -e ${VMFILE} ] && VM=`basename ${VMFILE}` || continue
    action $"  Starting VM: ${VM} ..." $SU "$VBOXMANAGE startvm "$VM" --type headless >/dev/null 2>/dev/null"
    RETVAL=$?
  done

  return $RETVAL
}

stop() {
  # NOTE: this stops all running VM's. Not just the ones listed in the $VBOX_LIST_D
  echo -n $"Stopping VirtualBox VMs: "
  vboxdrvrunning || {
   failure "VirtualBox kernel module not loaded!"
   exit 0
  }
  success
  [ $RETVAL = 0 ] && touch ${lockfile}
  echo

  $SU "$VBOXMANAGE list runningvms" | while read VM VMUUID; do
    action $"  Stopping VM: ${VM} ..." $SU "$VBOXMANAGE controlvm "$VM" acpipowerbutton >/dev/null 2>/dev/null"
    RETVAL=$?
  done

  action $"  Waiting for VMs to stop ..." wait_for_closing_machines

  return $RETVAL
}

restart() {
    stop && start
}

status() {
    echo $"Checking for running VirtualBox VMs: "
    enabled_vms=( ${VBOX_LIST_D}/* )
    running_vms=( `$SU "$VBOXMANAGE list runningvms" | awk '{print $1}'` )
    for VM in ${running_vms[@]}; do
      VM=`echo $VM | sed 's/\"//g'`
      ip=`$SU "$VBOXMANAGE guestproperty get "${VM}" /VirtualBox/GuestInfo/Net/0/V4/IP" | sed "s/^Value: //"`
      echo $"  ${VM} is running [ip: ${ip}]"
      for (( i = 0 ; i < ${#enabled_vms[@]} ; i++ )); do
        [ -e ${enabled_vms[$i]} ] || continue
        vmname=`basename ${enabled_vms[$i]}`
        if [ $vmname == $VM ]; then
          unset enabled_vms[$i]
        fi
        unset vmname
      done
    done
    for (( i = 0 ; i < ${#enabled_vms[@]} ; i++ )); do
      [ -e ${enabled_vms[$i]} ] || continue
      vmname=`basename ${enabled_vms[$i]}`
      echo $"  ${vmname} is NOT running"
      RETVAL=3
    done
}

startvm(){
  vmname=$1
  if [ -z "$vmname" ]; then
    echo "ERROR: You need to provide a vm name."
    exit 1
  fi
  
  action $"Sending start command: ${vmname} ..." $SU "$VBOXMANAGE startvm "$vmname" --type headless >/dev/null 2>/dev/null"
  RETVAL=$?
  
  return $RETVAL
}

deletevm(){
  vmname=$1
  if [ -z "$vmname" ]; then
    echo "ERROR: You need to provide a vm name."
    exit 1
  fi

  if [ ! -e "${VBOX_BASE}/${vmname}/${vmname}.vbox" ]; then
    echo "ERROR: The VM configuration file could not be found."
    exit 1
  fi
  
  action $"Sending unregistervm command: ${vmname} ..." $SU "$VBOXMANAGE unregistervm "$vmname" --delete >/dev/null 2>/dev/null"
  RETVAL=$?
  
  if [ "${RETVAL}" == 0 ]; then
    [ -e "${VBOX_BASE}/${vmname}" ] && action $"Removing VM files from ${VBOX_BASE}/${vmname} ..." rm -rf "${VBOX_BASE}/${vmname}"
  fi
  
  return $RETVAL
}

controlvm(){
  command=$1
  vmname=$2
  if [ -z "$vmname" ]; then
    echo "ERROR: You need to provide a vm name."
    exit 1
  fi
  
  action $"Sending ${command} command: ${vmname} ..." $SU "$VBOXMANAGE controlvm "$vmname" ${command} >/dev/null 2>/dev/null"
  RETVAL=$?
  
  return $RETVAL
}

case "$1" in
start)
    start
    ;;
stop)
    stop
    ;;
restart)
    restart
    ;;
force-reload)
    restart
    ;;
status)
    status
    ;;
shutdownvm)
    shift
    controlvm acpipowerbutton $@
    ;;
startvm)
    shift
    startvm $@
    ;;
poweroffvm)
    shift
    controlvm poweroff $@
    ;;
resetvm)
    shift
    controlvm reset $@
    ;;
deletevm)
    shift
    deletevm $@
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status|shutdownvm|startvm|poweroffvm|resetvm} [vmname]"
    exit 1
esac

exit $RETVAL
