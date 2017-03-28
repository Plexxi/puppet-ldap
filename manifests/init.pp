# == Class: ldap
#
# Puppet module to manage LDAP PAM and NSS configuration.
#
# === Parameters
#
# Document parameters here.
#
# [uri]
#   LDAP URI.  Multiple entries may be set.
#   **Required**
# [basedn]
#   LDAP default base dn
#   **Required**
# [binddn]
#   LDAP default bind dn
#   *Optional*
# [bindpw]
#   LDAP default bind password
#   *Optional*
# [pam_enable]
#   If enabled (pam_enable => true) enables the LDAP PAM module.
#   *Optional* (defaults to true)
# [nsswitch]
#   If enabled (nsswitch => true) enables nsswitch to use
#   LDAP as a backend for password, group and shadow databases.
#   *Optional* (defaults to false)
#
# === Examples
#
#  class { 'ldap':
#    uri => 'ldap://example.ldap.com ldap://another.ldap.com'
#    basedn => 'dc=suffix',
#    binddn => 'cn=bindUser'
#    bindpw => 'pass_word'
#  }
#
# === Authors
#
# Matthew Morgan <matt.morgan@plexxi.com>
#
# === Copyright
#
# Copyright 2016 Matthew Morgan, Plexxi, Inc
#
class ldap( 
  $uri,
  $basedn,
  $binddn     = undef,
  $bindpw     = undef,
  $pam_enable = true,
  $nsswitch   = false,
) {
  exec { 'ldap_name_restart':
       command => '/usr/sbin/service nscd restart && /usr/sbin/service nslcd restart',
  }
  if $pam_enable {
     file { '/etc/nslcd.conf':
       ensure  => file,
       owner   => 0,
       group   => 0,
       mode    => '0600',
       content => template('ldap/nslcd.conf.erb'),
     }
     exec { 'ldap_pam_auth_update':
       environment => ["DEBIAN_FRONTEND=editor",
                       "PLEXXI_AUTH_UPDATE=ldap",
                       "PLEXXI_AUTH_ENABLE=1",
                       "EDITOR=/opt/plexxi/bin/px-auth-update"],
       command => '/usr/sbin/pam-auth-update',
     }
     if $nsswitch {
       # setup/add ldap to nsswitch.conf
       augeas { 'ldap_nsswitch_add':
         context => "/files/etc/nsswitch.conf",
         onlyif  => "get /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[.='ldap'] == ''",
         changes => [
           "ins service after /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[last()]",
           "set /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[last()] ldap",
           "ins service after /files/etc/nsswitch.conf/*[self::database = 'group']/service[last()]",
           "set /files/etc/nsswitch.conf/*[self::database = 'group']/service[last()] ldap"
         ],
         notify => [ Exec[ldap_name_restart] ],
       }
     } else {
       # remove ldap from nsswitch.conf
       augeas { 'ldap_nsswitch_remove':
         context => "/files/etc/nsswitch.conf",
         changes => [
           "rm /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[.='ldap']",
           "rm /files/etc/nsswitch.conf/*[self::database = 'group']/service[.='ldap']",
         ],
         notify => [ Exec[ldap_name_restart] ],
       }
     }
  } else {
     exec { 'ldap_pam_auth_update':
       environment => ["DEBIAN_FRONTEND=editor",
                       "PLEXXI_AUTH_UPDATE=ldap",
                       "PLEXXI_AUTH_ENABLE=0",
                       "EDITOR=/opt/plexxi/bin/px-auth-update"],
       command => '/usr/sbin/pam-auth-update',
     }
     augeas { 'ldap_nsswitch_remove':
       context => "/files/etc/nsswitch.conf",
       changes => [
         "rm /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[.='ldap']",
         "rm /files/etc/nsswitch.conf/*[self::database = 'group']/service[.='ldap']",
       ],
       notify => [ Exec[ldap_name_restart] ],
     }
  }
}
