#!/bin/bash

docker-compose exec php /var/www/html/Search-Replace-DB-master/dbsearchreplace.sh "/^$1\$/" "$2" -g;
docker-compose exec php /var/www/html/Search-Replace-DB-master/dbsearchreplace.sh "://$1" "://$2"
