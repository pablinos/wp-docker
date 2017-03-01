FROM percona:latest

COPY tmp/wp_backup.sql /tmp/
COPY load_db.sh /
COPY backup.sh /
RUN chmod +x /load_db.sh
RUN chmod +x /backup.sh