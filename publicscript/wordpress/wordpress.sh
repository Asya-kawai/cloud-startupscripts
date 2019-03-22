#!/bin/bash

# @sacloud-name "WordPress"
# @sacloud-once

# @sacloud-desc WordPressをインストールします。
# @sacloud-desc サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
# @sacloud-desc http://サーバのIPアドレス/
# @sacloud-desc （このスクリプトは、CentOS6.Xでのみ動作します）
# @sacloud-require-archive distro-centos distro-ver-6.*

#---------START OF iptables---------#
cat <<'EOT' > /etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:fail2ban-SSH - [0:0]
-A INPUT -p tcp -m multiport --dports 22 -j fail2ban-SSH
-A INPUT -p TCP -m state --state NEW ! --syn -j DROP
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
-A INPUT -p udp --sport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A fail2ban-SSH -j RETURN
COMMIT
EOT
service iptables restart
#---------END OF iptables---------#
#---------START OF LAMP---------#
yum -y install expect httpd-devel mod_ssl php-devel php-pear mysql-server php-mbstring php-xml php-gd php-mysql|| exit 1
service httpd status >/dev/null 2>&1 || service httpd start

for i in {1..5}; do
sleep 1
service httpd status && break
[ "$i" -lt 5 ] || exit 1
done
chkconfig httpd on || exit 1

service mysqld status >/dev/null 2>&1 || service mysqld start
for i in {1..5}; do
sleep 1
service mysqld status && break
[ "$i" -lt 5 ] || exit 1
done
chkconfig mysqld on || exit 1

NEWMYSQLPASSWORD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`

/usr/bin/mysqladmin -u root password "$NEWMYSQLPASSWORD" || exit 1

cat <<EOT > /root/.my.cnf
[client]
host     = localhost
user     = root
password = $NEWMYSQLPASSWORD
socket   = /var/lib/mysql/mysql.sock
EOT
chmod 600 /root/.my.cnf
#---------END OF LAMP---------#
#---------START OF WordPress---------#
USERNAME="wp_`mkpasswd -l 10 -C 0 -s 0`"
PASSWORD=`mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2`
curl -L http://ja.wordpress.org/latest-ja.tar.gz | tar zxf - -C /var/www/ || exit 1
mv /var/www/wordpress /var/www/$USERNAME
cat <<EOT > /var/www/$USERNAME/wp-config.php
<?php
/** WordPress のためのデータベース名 */
define('DB_NAME', '$USERNAME');
/** MySQL データベースのユーザー名 */
define('DB_USER', '$USERNAME');
/** MySQL データベースのパスワード */
define('DB_PASSWORD', '$PASSWORD');
/** MySQL のホスト名 */
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
\$table_prefix  = 'wp_';
define('WPLANG', 'ja');
define('WP_DEBUG', false);
EOT

curl -L https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/$USERNAME/wp-config.php

cat <<'EOT' >> /var/www/$USERNAME/wp-config.php
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOT

mysql --defaults-file=/root/.my.cnf <<-EOT
CREATE DATABASE IF NOT EXISTS $USERNAME;
GRANT ALL ON $USERNAME.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';
FLUSH PRIVILEGES;
EOT

cat <<EOT > /etc/httpd/conf.d/$USERNAME.conf
<VirtualHost *:80>
DocumentRoot /var/www/$USERNAME
AllowEncodedSlashes On
<Directory />
     Options FollowSymLinks
     AllowOverride None
</Directory>
<Directory "/var/www/$USERNAME">
 Options FollowSymLinks MultiViews ExecCGI
    AllowOverride All
    Order allow,deny
    allow from all
</Directory>
</VirtualHost>
EOT
service httpd reload || exit 1

chown -R apache:apache /var/www || exit 1