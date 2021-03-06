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
# [ssl]
#   LDAP encryption.  Values are "on", "off", or "start_tls"
#   *Optional*
# [tls_reqcert]
#   LDAP encryption.  Values are "never", "allow", "try", "demand", or "hard"
#   *Optional*
# [tls_cacertfile]
#   LDAP encryption.  Path to X.509 certificate
#   *Optional*
# [tls_cert]
#   LDAP encryption.  Path to local certificate file for client TLS authentication
#   *Optional*
# [tls_key]
#   LDAP encryption.  Path to private key file for client TLS authentication
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
#    uri => ['ldap://example.ldap.com, ldap://another.ldap.com']
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
  Array[String] $uri,
  String  $basedn,
  Optional[String]  $binddn = undef,
  Optional[String]  $bindpw = undef,
  Pattern[/(?i:^on)/,
          /(?i:^off)/,  
          /(?i:^tls_cert)/] $ssl = "off",
  Optional[String] $tls_reqcert = undef,
  Optional[String] $tls_cacertfile = undef,
  Optional[String] $tls_cert = undef,
  Optional[String] $tls_key = undef,
  Boolean          $pam_enable = true,
  Boolean          $nsswitch   = false,
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
           "ins service before /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[1]",
           "set /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[1] ldap",
           "ins service before /files/etc/nsswitch.conf/*[self::database = 'group']/service[1]",
           "set /files/etc/nsswitch.conf/*[self::database = 'group']/service[1] ldap"
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
