#!/bin/bash
pushd .
cd /var/www/html/Search-Replace-DB-master
php srdb.cli.php -h $WORDPRESS_DB_HOST -n $MYSQL_DATABASE -u $MYSQL_USER -p $MYSQL_PASSWORD -s $1 -r $2 $3
popd
