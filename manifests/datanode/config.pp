# == Class hadoop::datanode::config
#
class hadoop::datanode::config {
  include ::stdlib
  contain hadoop::common::config
  contain hadoop::common::hdfs::config
  contain hadoop::common::hdfs::daemon

  $keytab = $hadoop::keytab_datanode
  $keytab_source = $hadoop::keytab_source_datanode
  $user = 'hdfs'
  $file = '/tmp/krb5cc_dn'
  $principal = "dn/${::fqdn}@${hadoop::realm}"
  # for templates in env/*
  $krbrefresh = $hadoop::features["krbrefresh"]
  $realm = $hadoop::realm

  # ensure proper owner and group
  # (better to enable sticky bit for more protection)
  ensure_resource('file', $hadoop::_hdfs_data_storages['paths'], {
    ensure => directory,
    owner  => 'hdfs',
    group  => 'hadoop',
    mode   => '1755',
  })

  if $hadoop::realm and $hadoop::realm != '' {
    if $keytab_source and $keytab_source != '' {
      file { $keytab:
        owner  => 'hdfs',
        group  => 'hdfs',
        mode   => '0400',
        alias  => 'dn.service.keytab',
        source => $keytab_source,
        }
    } else {
      file { $keytab:
        owner => 'hdfs',
        group => 'hdfs',
        mode  => '0400',
        alias => 'dn.service.keytab',
        }
    }
    if $hadoop::keytab_source_http and $hadoop::keytab_source_http != '' {
      file { $hadoop::https_keytab:
        owner  => 'hdfs',
        group  => 'hdfs',
        mode   => '0400',
        alias  => 'http.service.keytab',
        before => File['hdfs-site.xml'],
        source => $hadoop::keytab_source_http,
      }
    } else {
      file { $hadoop::https_keytab:
        owner  => 'hdfs',
        group  => 'hdfs',
        mode   => '0400',
        alias  => 'http.service.keytab',
        before => File['hdfs-site.xml'],
      }
    }

    if $hadoop::features["krbrefresh"] {
      $cron_ensure = 'present'
    } else {
      $cron_ensure = 'absent'
    }
    file { '/etc/cron.d/hadoop-datanode-krb5cc':
      ensure  => $cron_ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      alias   => 'dn-cron',
      content => template('hadoop/cron.erb'),
    }

    if $hadoop::features["krbrefresh"] {
      exec { 'dn-kinit':
        command     => "kinit -k -t ${keytab} ${principal}",
        user        => $user,
        path        => '/bin:/usr/bin',
        environment => [ "KRB5CCNAME=FILE:${file}" ],
        creates     => $file,
      }

      File[$keytab] -> Exec['dn-kinit']
    }
  }

  $env_datanode = $hadoop::envs['datanode']
  augeas{$env_datanode:
    lens    => 'Shellvars.lns',
    incl    => $env_datanode,
    changes => template('hadoop/env/hdfs-datanode.augeas.erb'),
  }
  #notice(template('hadoop/env/hdfs-datanode.augeas.erb'))
}
