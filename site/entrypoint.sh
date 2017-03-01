#!/bin/bash
set -euo pipefail

if ! [ -e index.php -a -e wp-includes/version.php ]; then
  echo >&2 "WordPress not found in $(pwd) - copying now..."
  if [ "$(ls -A)" ]; then
    echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
    ( set -x; ls -A; sleep 10 )
  fi
  tar cf - --one-file-system -C /usr/src/wordpress . | tar xf -
  echo >&2 "Complete! WordPress has been successfully copied to $(pwd)"

  echo >&2 "Adding MySQL search replace tool"
  cp -R /usr/src/Search-Replace-DB-master .

fi

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

file_env 'WORDPRESS_DB_HOST' 'mysql'
# if we're linked to MySQL and thus have credentials already, let's use them
file_env 'WORDPRESS_DB_USER' "${MYSQL_USER:-root}"
if [ "$WORDPRESS_DB_USER" = 'root' ]; then
  file_env 'WORDPRESS_DB_PASSWORD' "${MYSQL_ROOT_PASSWORD:-}"
else
  file_env 'WORDPRESS_DB_PASSWORD' "${MYSQL_PASSWORD:-}"
fi
file_env 'WORDPRESS_DB_NAME' "${MYSQL_DATABASE:-wordpress}"
if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
  echo >&2 'error: missing required WORDPRESS_DB_PASSWORD environment variable'
  echo >&2 '  Did you forget to -e WORDPRESS_DB_PASSWORD=... ?'
  echo >&2
  echo >&2 '  (Also of interest might be WORDPRESS_DB_USER and WORDPRESS_DB_NAME.)'
  exit 1
fi


SEDCMD=sed

# TODO handle WordPress upgrades magically in the same way, but only if wp-includes/version.php's $wp_version is less than /usr/src/wordpress/wp-includes/version.php's $wp_version

# version 4.4.1 decided to switch to windows line endings, that breaks our seds and awks
# https://github.com/docker-library/wordpress/issues/116
# https://github.com/WordPress/WordPress/commit/1acedc542fba2482bab88ec70d4bea4b997a92e4
$SEDCMD -ri -e 's/\r$//' wp-config*


# see http://stackoverflow.com/a/2705678/433558
sed_escape_lhs() {
  echo "$@" | $SEDCMD -e 's/[]\/$*.^|[]/\\&/g'
}
sed_escape_rhs() {
  echo "$@" | $SEDCMD -e 's/[\/&]/\\&/g'
}
php_escape() {
  if [ "$2" = "string" ]
  then
    printf "\'%s\'" "$(echo "$1" | sed "s/'/\\\'/g")"
  else
    echo "$1"
  fi
}
set_config() {
  key="$1"
  value="$2"
  var_type="${3:-string}"
  start="(['\"])$(sed_escape_lhs "$key")\2\s*,"
  end="\);"
  if [ "${key:0:1}" = '$' ]; then
    start="^(\s*)$(sed_escape_lhs "$key")\s*="
    end=";"
  fi
#  $SEDCMD -ri -e "s/($start\s*).*($end)$/\1$(sed_escape_rhs "$(php_escape "$value" "$var_type")")\3/" wp-config.php
  $SEDCMD -ri -e "s/($start\s*).*($end)$/\1$(sed_escape_rhs "$(php_escape "$value" "$var_type")")\3/" wp-config.php
}


file_env 'WORDPRESS_MULTISITE'

if [ "$WORDPRESS_MULTISITE" ]; then
  WPMU=(
    SUBDOMAIN_INSTALL
    DOMAIN_CURRENT_SITE
    PATH_CURRENT_SITE
    SITE_ID_CURRENT_SITE
    BLOG_ID_CURRENT_SITE
  )
  for mu in "${WPMU[@]}"; do
    muVar="WORDPRESS_$mu"
    file_env "$muVar"
  done
fi

if [ ! -e wp-config.php ]; then
  awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' wp-config-sample.php > wp-config.php <<'EOPHP'
define('WP_ALLOW_MULTISITE', false );

// If we're behind a proxy server and using HTTPS, we need to alert Wordpress of that fact
// see also http://codex.wordpress.org/Administration_Over_SSL#Using_a_Reverse_Proxy
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
	$_SERVER['HTTPS'] = 'on';
}
EOPHP
#  chown www-data:www-data wp-config.php

  if [ "$WORDPRESS_MULTISITE" ]; then

    cat <<EOF | awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' wp-config.php > tmp-config.php
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', ${WORDPRESS_SUBDOMAIN_INSTALL} );
define('DOMAIN_CURRENT_SITE', '${WORDPRESS_DOMAIN_CURRENT_SITE}' );
define('PATH_CURRENT_SITE', '${WORDPRESS_PATH_CURRENT_SITE}');
define('SITE_ID_CURRENT_SITE', ${WORDPRESS_SITE_ID_CURRENT_SITE});
define('BLOG_ID_CURRENT_SITE', ${WORDPRESS_BLOG_ID_CURRENT_SITE});

EOF
    
    mv tmp-config.php wp-config.php

  fi

else

  if [ "$WORDPRESS_MULTISITE" ]; then

    set_config 'SUBDOMAIN_INSTALL' $WORDPRESS_SUBDOMAIN_INSTALL boolean
    set_config 'DOMAIN_CURRENT_SITE' $WORDPRESS_DOMAIN_CURRENT_SITE
    set_config 'PATH_CURRENT_SITE' $WORDPRESS_PATH_CURRENT_SITE
    set_config 'SITE_ID_CURRENT_SITE' $WORDPRESS_SITE_ID_CURRENT_SITE
    set_config 'BLOG_ID_CURRENT_SITE' $WORDPRESS_BLOG_ID_CURRENT_SITE

  fi
fi

file_env 'WORDPRESS_ALLOW_MULTISITE'
if [ "$WORDPRESS_ALLOW_MULTISITE" ]; then
  set_config 'WP_ALLOW_MULTISITE' true boolean
fi




set_config 'DB_HOST' "$WORDPRESS_DB_HOST"
set_config 'DB_USER' "$WORDPRESS_DB_USER"
set_config 'DB_PASSWORD' "$WORDPRESS_DB_PASSWORD"
set_config 'DB_NAME' "$WORDPRESS_DB_NAME"

# allow any of these "Authentication Unique Keys and Salts." to be specified via
# environment variables with a "WORDPRESS_" prefix (ie, "WORDPRESS_AUTH_KEY")
UNIQUES=(
  AUTH_KEY
  SECURE_AUTH_KEY
  LOGGED_IN_KEY
  NONCE_KEY
  AUTH_SALT
  SECURE_AUTH_SALT
  LOGGED_IN_SALT
  NONCE_SALT
)
for unique in "${UNIQUES[@]}"; do
  uniqVar="WORDPRESS_$unique"
  file_env "$uniqVar"
  if [ "${!uniqVar}" ]; then
    set_config "$unique" "${!uniqVar}"
  else
    # if not specified, let's generate a random value
    current_set="$($SEDCMD -rn -e "s/define\((([\'\"])$unique\2\s*,\s*)(['\"])(.*)\3\);/\4/p" wp-config.php)"
    if [ "$current_set" = 'put your unique phrase here' ]; then
      set_config "$unique" "$(LC_ALL=C tr -cd '\41-\46\50-\133\135-\176' < /dev/urandom | head -c 64)"
    fi
  fi
done

file_env 'WORDPRESS_TABLE_PREFIX'
if [ "$WORDPRESS_TABLE_PREFIX" ]; then
  set_config '$table_prefix' "$WORDPRESS_TABLE_PREFIX"
fi

file_env 'WORDPRESS_DEBUG'
if [ "$WORDPRESS_DEBUG" ]; then
  set_config 'WP_DEBUG' true boolean
fi


