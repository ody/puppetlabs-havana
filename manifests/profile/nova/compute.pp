# The puppet module to set up a Nova Compute node
class havana::profile::nova::compute {

  $controller_address = hiera('havana::controller::address::management')
  $storage_address = hiera('havana::storage::address::management')

  $api_device = hiera('havana::network::api::device')
  $api_address = getvar("ipaddress_${api_device}")

  $management_device = hiera('havana::network::management::device')
  $management_address = getvar("ipaddress_${management_device}")


  $data_device = hiera('havana::network::data::device')
  $data_address = getvar("ipaddress_${data_device}")

  $sql_password = hiera('havana::nova::sql::password')
  $sql_connection = "mysql://nova:${sql_password}@${management_address}/nova"

  class { 'havana::profile::nova::common':
    is_compute => true,
  }

  class { '::nova::compute::libvirt':
    libvirt_type     => hiera('havana::nova::libvirt_type'),
    vncserver_listen => $management_address,
  }

  # This may only be necessary for RHEL family systems
  file { '/etc/libvirt/qemu.conf':
    ensure => present,
    source => 'puppet:///modules/havana/qemu.conf',
    mode   => '0644',
    notify => Service['libvirtd'],
  }

  # because firewall is not compatible with libvirtd, we need to flush
  # and update rules and services

  # exec rules for stopping libvirtd
  exec { '/sbin/service libvirtd stop': 
    notify  => Service['libvirt'],
    returns => [0, 1],
  }

  # clear the libvirtd masquerade rule
  exec { '/sbin/iptables -t nat -F POSTROUTING': }

  Exec['/sbin/service libvirtd stop'] -> 
  Exec['/sbin/iptables -t nat -F POSTROUTING'] -> 
  Class['::firewall'] 
  #Firewall['00001 - related established']

  Firewall['99999 - Reject remaining traffic'] -> Service['libvirt']
}
