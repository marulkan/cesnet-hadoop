# == Class hadoop::datanode::service
#
class hadoop::datanode::service {
  service { 'hadoop-datanode':
    ensure    => 'running',
    enable    => true,
    subscribe => [File['core-site.xml'], File['hdfs-site.xml']],
  }

  if $hadoop::realm and $hadoop::features["krbrefresh"] {
    File['dn-env'] ~> Service['hadoop-datanode']
  }
}
