#!/bin/sh

# $Id: rc-local-virtualbox-server.sh 6336 2011-02-10 05:47:18Z $

# --- if /VirtualMachines is a mountpoint then remount w/ noatime option.
/bin/mountpoint -q /VirtualMachines && mount -o remount,noatime /VirtualMachines

touch /var/lock/subsys/local
