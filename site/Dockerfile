FROM debian:wheezy


RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y \
		curl \
	; \
	rm -rf /var/lib/apt/lists/*; 


# Taken from official WordPress Dockerfile - https://github.com/docker-library/wordpress/
ENV WORDPRESS_VERSION 4.7.2
ENV WORDPRESS_SHA1 7b687f1af589c337124e6247229af209ec1d52c3

RUN set -ex; \
	curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
	echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -; \
# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
	tar -xzf wordpress.tar.gz -C /usr/src/; \
	rm wordpress.tar.gz; \
	chown -R www-data:www-data /usr/src/wordpress ; \
        curl -o searchreplace.tar.gz -fSL "https://github.com/interconnectit/Search-Replace-DB/archive/master.tar.gz"; \
        tar -xzf searchreplace.tar.gz -C /usr/src/;

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY dbsearchreplace.sh /usr/src/Search-Replace-DB-master
RUN chmod +x /usr/src/Search-Replace-DB-master/dbsearchreplace.sh

WORKDIR /var/www/html

VOLUME /var/www/html/wp-content

ENTRYPOINT ["entrypoint.sh"]