# Class: auditserver
#
# This module manages auditserver
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class auditserver (
  $libpath    = 'USE_DEFAULTS',
  $file_name  = '/usr/bin/auditserver.pl',
  $file_owner = 'root',
  $file_group = 'root',
  $file_mode  = '755',
  $url        = 'USE_DEFAULTS',
  $site       = 'USE_DEFAULTS',
  $file_ensure  = 'present',
  $cron_month = '11',
  $cron_day  = '22',
  $cron_hour = '12',
  $cron_min  = '0',
) {


  case $site {
    cnsh : {
            $default_url = 'http://ecnshwdp2001.rnd.ericsson.se:8099/service-dispatch/object'
            $default_libpath = '/proj/cnshrepo/lib/linux'
  }
    seki : {
            $default_url = 'http://esekiwdp365.rnd.ericsson.se:8099/service-dispatch/object'
            $default_libpath = '/proj/BIIT360/cron/lib/linux'
  }
    default: { fail('the site is not in scope') }
  }

  if $libpath == 'USE_DEFAULTS' {
    $libpath_real = $default_libpath
  } else {
    $libpath_real = $libpath
  }


  if $url == 'USE_DEFAULTS' {
    $url_real = $default_url
  } else {
    $url_real = $url
  }

  file { 'auditserver_pl':
    path    => $file_name,
    owner   => $file_owner,
    group   => $file_group,
    mode    => $file_mode,
    content => template('auditserver/auditEISserver.erb')
  }

  cron { 'auditserver_run':
    command  => "${file_name} ${site}",
    user     => $file_owner,
    month    => $cron_month,
    monthday => $cron_day,
    hour     => $cron_hour,
    minute   => $cron_min,
  }


}
