#!/bin/bash
# usage: xon client_host client_port
# or just: xon (then client host will be taken from host and client port will be default 9003)

HOST_IP=$([ -n "$1" ] && echo $1 || /sbin/ip route | awk '/default/ { print $3 }')
HOST_PORT=$([ -n "$2" ] && echo $2 || echo 9003)

mv /usr/local/etc/php/conf.d/xdebug.off /usr/local/etc/php/conf.d/xdebug.ini

sed -i "s|xdebug.client_host=.*|xdebug.client_host=$HOST_IP|" $PHP_INI_DIR/conf.d/xdebug.ini
sed -i "s|xdebug.client_port=.*|xdebug.client_port=$HOST_PORT|" $PHP_INI_DIR/conf.d/xdebug.ini

pkill -o -USR2 php-fpm
