#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.

[ -x /opt/clivepeeters/sbin/virtualbox_client_builder.sh ] && echo "/opt/clivepeeters/sbin/virtualbox_client_builder.sh" | at now

touch /var/lock/subsys/local
