# $Id: init.pp 6357 2011-02-15 03:24:34Z $

import "defines/*.pp"

class virtualbox {
  modules_dir { "virtualbox": }

  package { [ "dkms", "kernel-devel", "make" ]: ensure => installed; }

  include gcc

  class host inherits virtualbox {
    repo { "virtualbox": path => "/virtualbox/centos/\$releasever/\$basearch/", priority => 5, gpgkey => "${default_yum_repo}/virtualbox/oracle_vbox.asc"; }

    package { "VirtualBox-4.0": ensure => installed, alias => "virtualbox", require => [ Repo["virtualbox"], Package[ "dkms", "gcc", "kernel-devel" ], Class["repos"] ]; }

    realize ( User["vbox"] )

    file { "/etc/rc.d/init.d/vboxcontrol": source => "${fserver}/modules/virtualbox/vboxcontrol-init.sh", mode => 750;
           "/usr/local/sbin/virtualbox_create.sh": source => "${fserver}/modules/virtualbox/virtualbox_create.sh", mode => 750;
           "/etc/vbox/vbox.cfg": content => "VBOXWEB_USER=vbox\nVBOXWEB_HOST=${ipaddress_eth0}\n", require => [ Package["virtualbox"], User["vbox"] ];
           "/etc/sysconfig/vboxcontrol":  content => "VBOX_USER=vbox\n";
           "/VirtualMachines": ensure => directory, owner => vbox;
           "/etc/rc.d/rc.local": source => "${fserver}/modules/virtualbox/rc-local-virtualbox-server.sh", mode => 755;

           [ "/etc/vbox/machines_enabled.d", "/etc/vbox/machines.d" ]:
             source  => "${fserver}/modules/local/empty",
             ensure  => directory,
             recurse => true,
             purge   => true,
             mode    => 0755,
             require => Package["virtualbox"];
    }

    service { "vboxcontrol": enable => true, require => [ Package["virtualbox"], File["/etc/rc.d/init.d/vboxcontrol","/etc/vbox/machines_enabled.d","/etc/sysconfig/vboxcontrol"] ]; }

    include rsync
    exec { "download_virtualbox_extpack": command => "/usr/bin/rsync --copy-links --inplace rsync://${default_yum_repo}/virtualbox/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack",
                                          cwd => "/opt", refreshonly => true, timeout => 2100, before => Exec["setup_virtualbox_extpack"], require => Class["rsync"];

           "prime_download_virtualbox_extpack": command => "/bin/true prime_download_virtualbox_extpack", notify => Exec["download_virtualbox_extpack"],
                                                creates => "/opt/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack";

           "setup_virtualbox_extpack": command => "/bin/sh -c '/usr/bin/VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack'",
                                       cwd => "/opt", refreshonly => true, timeout => 600, require => [ Exec["download_virtualbox_extpack"], Package["virtualbox"] ];

           "/bin/true setup_virtualbox_extpack": creates => "/usr/lib/virtualbox/ExtensionPacks/Oracle_VM_VirtualBox_Extension_Pack", notify => [ Exec["download_virtualbox_extpack"], Exec["setup_virtualbox_extpack"] ];
    }

    sysctl { "vm.swappiness":             value => "0";
             "vm.overcommit_memory":      value => "1";
             "vm.dirty_background_ratio": value => "5";
             "vm.dirty_ratio":            value => "10";
             "vm.dirty_expire_centisecs": value => "1000";
             "dev.rtc.max-user-freq":     value => "1024";
    }
  }

  class guest inherits virtualbox {
    include rsync
    include zerofree::sysinit

    exec { "download_virtualbox_additions": command => "/usr/bin/rsync --copy-links --inplace rsync://${default_yum_repo}/virtualbox/VBoxLinuxAdditions.run VBoxLinuxAdditions.run",
                                            cwd => "/opt", refreshonly => true, timeout => 2100, before => Exec["setup_virtualbox_additions"], require => Class["rsync"];

           "prime_download_virtualbox_additions": command => "/bin/true prime_download_virtualbox_additions", notify => Exec["download_virtualbox_additions"],
                                                  creates => "/opt/VBoxLinuxAdditions.run";

           "setup_virtualbox_additions": command => "/bin/sh -c '/opt/VBoxLinuxAdditions.run'",
                                         cwd => "/opt", refreshonly => true, timeout => 600, require => [ Exec["download_virtualbox_additions"], Package["kernel-devel","dkms"], Class["gcc"] ];

           "/bin/true setup_virtualbox_additions": unless => "/sbin/lsmod | /bin/grep -q ^vboxguest", notify => [ Exec["download_virtualbox_additions"], Exec["setup_virtualbox_additions"] ];
    }

    if $virtualbox_additions_version {
      if $virtualbox_additions_version != $default_virtualbox_additions_version {
        exec { "/bin/true setup_virtualbox_additions_version": notify => [ Exec["download_virtualbox_additions"], Exec["setup_virtualbox_additions"] ]; }
      }
    }

    case $operatingsystem {
      centos,redhat: {
        $good_kernel_options = "nodmraid divider=10"
        $bad_kernel_options  = "clocksource=acpi_pm clock=pmtmr notsc"

        exec { "setup_virtualbox_kernel_options":
                     command => "/sbin/grubby --update-kernel=DEFAULT --remove-args=\"$good_kernel_options $bad_kernel_options\" && /sbin/grubby --update-kernel=DEFAULT --args=\"$good_kernel_options\"",
                     unless  => "/sbin/grubby --info=DEFAULT | grep args= | grep -q \"$good_kernel_options\"",
        }
      }
    }
  }
}
