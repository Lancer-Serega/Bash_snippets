#!/usr/bin/env bash

. /vagrant/workenv/bootstrap.conf

# env
# ---
export DEBIAN_FRONTEND=noninteractive

# common
# ------
apt-get update
apt-get -y install curl
apt-get -y install htop   # system monitor in terminal
apt-get -y install ranger # file manager in terminal
apt-get -y install tree   # See directory tree structure in terminal

# git
# ---
apt-get -y install git

# mysql
# -----
debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password password rootpass'
debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password_again password rootpass'
apt-get -y install mysql-server php5-mysql
echo "CREATE USER '${MYSQL_USER}'@'${MYSQL_USER_HOST}' IDENTIFIED BY '${MYSQL_PASS}'" | mysql -uroot -prootpass
echo "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'${MYSQL_USER_HOST}' WITH GRANT OPTION" | mysql -uroot -prootpass
echo "FLUSH PRIVILEGES" | mysql -uroot -prootpass
sed -i 's/^bind-address.*/bind-address=0.0.0.0/' /etc/mysql/my.cnf
sed -i '/\[client\]/a default-character-set=utf8' /etc/mysql/my.cnf
sed -i '/\[mysql\]/a default-character-set=utf8' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a collation-server=utf8_unicode_ci' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a character-set-server=utf8' /etc/mysql/my.cnf
service mysql restart

# nginx
# -----
apt-get -y install nginx
cat "/vagrant/workenv/site.conf" > /etc/nginx/sites-available/default
service nginx restart

# php-fpm
# -------
echo "deb http://packages.dotdeb.org wheezy-php56 all" >> /etc/apt/sources.list.d/dotdeb.list
echo "deb-src http://packages.dotdeb.org wheezy-php56 all" >> /etc/apt/sources.list.d/dotdeb.list
wget http://www.dotdeb.org/dotdeb.gpg -O- | apt-key add -
apt-get update
apt-get -y install php5-cli php5-fpm php5-xdebug php5-gd php5-curl php5-intl \
    php5-mcrypt
php_ini_set() {
    ini_file=$1
    if [ $ini_file = '/etc/php5/fpm/php.ini' ]; then
        sed -i "s/^memory_limit.*/memory_limit=${PHP_MEMORY_LIMIT}/" $ini_file
        sed -i 's/^;cgi.fix_pathinfo.*/cgi.fix_pathinfo=0/' $ini_file
    fi
    sed -i "s/^max_execution_time.*/max_execution_time=${PHP_EXECUTION_TIME}/" $ini_file
    sed -i "s/^max_input_time.*/max_input_time=${PHP_INPUT_TIME}/" $ini_file
    sed -i "s/^error_reporting.*/error_reporting=${PHP_ERROR_REPORTING}/" $ini_file
    sed -i "s/^display_errors.*/display_errors=${PHP_DISPLAY_ERRORS}/" $ini_file
    sed -i "s/^display_startup_errors.*/display_startup_errors=${PHP_DISPLAY_STARTUP_ERRORS}/" $ini_file
    sed -i "s/^track_errors.*/track_errors=${PHP_TRACK_ERRORS}/" $ini_file
    esc_tz=$(echo $TIME_ZONE | sed 's/\//\\&/')
    sed -i "s/^;date\.timezone.*/date.timezone=${esc_tz}/" $ini_file
}
php_ini_set /etc/php5/fpm/php.ini
php_ini_set /etc/php5/cli/php.ini
xdebug_set() {
    ini_file=$1
    ide_key=$2
    remote_host=$3

    xdebug=$(cat <<EOF
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_log=/tmp/php5.6-xdebug.log
xdebug.idekey=${ide_key}
xdebug.remote_host=${remote_host}
xdebug.max_nesting_level=1000
EOF
)

    echo "${xdebug}" > $ini_file
}
foreign_ip=$(netstat -rn | grep "^0.0.0.0 " | cut -d " " -f10)
xdebug_set /etc/php5/cli/conf.d/50-xdebug.ini $XDEBUG_IDEKEY $foreign_ip
xdebug_set /etc/php5/fpm/conf.d/50-xdebug.ini $XDEBUG_IDEKEY $MACHINE_IP
service php5-fpm restart

# composer
# --------
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
echo "export COMPOSER_DISABLE_XDEBUG_WARN=1" >> /home/vagrant/.profile
if [ -n $GITHUB_OAUTH_TOKEN ]; then
    composer config -g github-oauth.github.com $GITHUB_OAUTH_TOKEN
fi

# bower
# -----
apt-get -y install apt-transport-https ca-certificates
echo "deb https://deb.nodesource.com/clang-3.4 wheezy main" >> /etc/apt/sources.list
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
apt-get update
apt-get -y install clang-3.4
CC=/usr/bin/clang
export CC
CXX=/usr/bin/clang++
export CXX
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
apt-get -y install nodejs build-essential
npm install -g bower

# link to site
# ------------
rm -rf /usr/share/nginx/www
ln -s /vagrant /usr/share/nginx/www

# reset home directory
# --------------------
echo "cd /usr/share/nginx/www" >> /home/vagrant/.profile

# time zone
# ---------
echo $TIME_ZONE > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# done
# ----
echo -en "** \e[32;5;1m[Done]\e[32;2m Visit '\e[36;5;1mhttp://${MACHINE_IP}\e[32;2m' in your browser for to view the application **\n"
echo -en "** \e[32;5;1m[Done]\e[32;2m Connect to '\e[36;5;1m${MYSQL_USER}@${MACHINE_IP}:3306\e[32;2m' with password '\e[36;5;1m${MYSQL_PASS}\e[32;2m' via your database client **\n"
