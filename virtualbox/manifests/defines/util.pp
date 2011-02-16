# $Id: util.pp 6318 2011-02-09 23:21:54Z $

define virtualbox::managed_file ()
{
    $dir = "${modules_dir}/virtualbox/${title}.d"

    concatenated_file { "${modules_dir}/virtualbox/${title}": dir => $dir, mode => 0600 }
}

define virtualbox::entry ($line)
{
  $target = "${modules_dir}/virtualbox/${title}"
  $dir    = dirname($target)

  file { $target:
           content => "${line}\n",
           mode    => 0600,
           owner   => root,
           group   => root,
           notify  => Exec["concat_${dir}"]
  }
}
