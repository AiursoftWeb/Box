<?php
$CONFIG = array (
  'default_phone_region' => 'CN',
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'instanceid' => 'ocwtwv9w68t1',
  'passwordsalt' => 'vxs3h2yXEQ4I8wvPSZvklNK564q4Yq',
  'secret' => 'y4VqY2aP1j2iZ/emCq1ssQJ0TAnQt2SM4FRU5mU0h+iLovdM',
  'trusted_domains' => 
  array (
    0 => 'localhost:2025',
  ),
  'trusted_proxies' => 
  array (
    0 => 'caddy',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'sqlite3',
  'version' => '27.0.2.1',
  'overwrite.cli.url' => 'http://localhost:2025',
  'installed' => true,
);
