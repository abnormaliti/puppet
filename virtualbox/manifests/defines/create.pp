# $Id: create.pp 6331 2011-02-10 03:37:18Z $

define virtualbox::host::create ( $memory          = "1500",
                                  $port            = "3389",
                                  $enable_nic2     = "0",
                                  $enable_nic3     = "0",
                                  $bridge_nic2     = "eth1",
                                  $bridge_nic3     = "eth2",
                                  $ostype          = "RedHat",
                                  $hddtemplatename = "vboxtemplate-i386.vdi.gz",
                                  $base            = "/VirtualMachines",
                                  $enable          = false,
                                  $hdd2            = '',
                                  $hdd2size        = "80000",
                                  $hdd2file        = '',
                                  $order           = 100
                                )
{
  virtualbox::managed_file { "${title}.vbox": }

  file { "/etc/vbox/machines.d/${title}": source => "${modules_dir}/virtualbox/${title}.vbox", require => Class["virtualbox::host"],
                                          subscribe => Exec["concat_${modules_dir}/virtualbox/${title}.vbox"];
  }

  exec { "/bin/echo \"/usr/local/sbin/virtualbox_create.sh /etc/vbox/machines.d/${title}\" | /usr/bin/at now && sleep 10":
           creates => "${base}/${title}", require => [ Class["virtualbox::host"], File["/etc/vbox/machines.d/${title}"] ];
  }

  virtualbox::entry {
    "${title}.vbox.d/${order}-name":            line => "NAME=${title}";
    "${title}.vbox.d/${order}-memory":          line => "MEMORY=${memory}";
    "${title}.vbox.d/${order}-port":            line => "PORT=${port}";
    "${title}.vbox.d/${order}-enable_nic2":     line => "ENABLE_NIC2=${enable_nic2}";
    "${title}.vbox.d/${order}-enable_nic3":     line => "ENABLE_NIC3=${enable_nic3}";
    "${title}.vbox.d/${order}-bridge_nic2":     line => "BRIDGE_NIC2=${bridge_nic2}";
    "${title}.vbox.d/${order}-bridge_nic3":     line => "BRIDGE_NIC3=${bridge_nic3}";
    "${title}.vbox.d/${order}-ostype":          line => "OSTYPE=${ostype}";
    "${title}.vbox.d/${order}-hddtemplatename": line => "HDDTEMPLATENAME=${hddtemplatename}";
    "${title}.vbox.d/${order}-base":            line => "BASE=${base}";
    "${title}.vbox.d/${order}-disabled":        line => "disabled=0";
  }

  if $hdd2 {
    virtualbox::entry {
      "${title}.vbox.d/${order}-hdd2":     line => "HDD2=${hdd2}";
      "${title}.vbox.d/${order}-hdd2size": line => "HDD2SIZE=${hdd2size}";
    }
    if $hdd2file {
      virtualbox::entry {
        "${title}.vbox.d/${order}-hdd2file": line => "HDD2FILE=${hdd2file}";
      }
    }
  }

  if $enable {
    file { "/etc/vbox/machines_enabled.d/${title}": ensure => "/etc/vbox/machines.d/${title}", require => [ Class["virtualbox::host"], File["/etc/vbox/machines.d/${title}"] ]; }
  }
}
