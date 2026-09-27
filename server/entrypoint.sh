#!/bin/bash
set -e

DB_PASS=123456

# Hostnames the PW services use to find each other
echo "127.0.0.1 database dbserver gm_server PW-Server aumanager manager link1 link2 link3 link4 game1 game2 game3 game4 delivery backup auth audb gmserver LOCAL0 LogServer AUDATA" >> /etc/hosts

# MariaDB data lives on a host volume. The first run creates it and imports the dumps.
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    FIRST_RUN=1
fi

chown -R mysql:mysql /var/lib/mysql
setsid mysqld_safe --user=mysql --datadir=/var/lib/mysql &

until mariadb-admin ping --silent; do
    sleep 1
done

if [ -n "$FIRST_RUN" ]; then
    mariadb -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE DATABASE pw176;
CREATE DATABASE licenseservice;
FLUSH PRIVILEGES;
SQL
    mariadb -u root -p"$DB_PASS" pw176 < /root/sql/pw176.sql
    mariadb -u root -p"$DB_PASS" licenseservice < /root/sql/licenseservice.sql
fi

# The dump sets the license end to 2090, but UNIX_TIMESTAMP() in MariaDB 10.11
# returns NULL after 2038. licenseservice then reports "license time out" and
# every daemon quits on SIGUSR1 (the "server stops at 30%" symptom).
mariadb -u root -p"$DB_PASS" licenseservice \
    -e "UPDATE users SET time_end='2037-12-31 00:00:00' WHERE time_end > '2037-12-31';"

chmod -R 777 /root/pwserver

# PW daemons send SIGUSR1 to their parent on startup. Sourcing the control
# script into a bash that traps USR1 keeps it alive long enough to start everything.
setsid bash -c "trap 'true' USR1; . /root/server start" || true

# On docker stop: stop the game first, then MariaDB, so both flush their data
shutdown() {
    /root/server stop
    mariadb-admin -u root -p"$DB_PASS" shutdown
    exit 0
}

trap shutdown TERM INT

# Keep the container alive and surface the logs. wait lets the trap fire.
tail -F /root/pwserver/logs/*.log &
wait $!
