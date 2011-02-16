#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.

[ -x /usr/local/sbin/virtualbox_client_builder.sh ] && nohup /usr/local/sbin/virtualbox_client_builder.sh >/dev/null 2>&1 &

touch /var/lock/subsys/local
