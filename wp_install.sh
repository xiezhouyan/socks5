#!/bin/bash
# centos7/8 WordPress一键安装脚本
# Author: tlanyan
# link: https://tlanyan.me

red='\033[0;31m'
plain='\033[0m'

function checkSystem()
{
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        echo "请以root身份执行该脚本"
        exit 1
    fi

    if [ ! -f /etc/lsb-release ];then
        echo "系统不是Ubuntu"f
        exit 1
    fi
}

function collect()
{
    while true
    do
        read -p "请输入您的域名：" domain
        if [ ! -z "$domain" ]; then
            break
        fi
    done
}

function preInstall()
{
    apt install python-software-properties -y
    add-apt-repository ppa:ondrej/php -y
    apt-get update -y
    apt-get install vim git -y
}

function installNginx()
{
    apt-get install nginx -y
    systemctl enable nginx
    systemctl restart nginx
}

function installPHP()
{
    apt-get install php7.4 php7.4-fpm php7.4-mysql php7.4-cli -y 
    systemctl restart php7.4-fpm.service
}

function installMysql()
{
    apt-get install mariadb-server -y;
    systemctl restart mariadb.
}


function installWordPress()
{
    if [ ! -f /usr/local/bin/wp ];then
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        php wp-cli.phar --info
	chmod +x wp-cli.phar
	sudo mv wp-cli.phar /usr/local/bin/wp
    fi
    echo "WordPress Core Install"
    mkdir -p /var/www/${domain};
    cd /var/www/${domain};
    wp core download --allow-root
    wp config create --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbhost=127.0.0.1 --dbprefix=wp --allow-root
    wp core install --url=$domain --title=$domain --admin_user=admin --admin_password=admin@qwe!123 --admin_email=wp_admin@163.com --allow-root 
    wp theme install hello-elementor --allow-root 
    wp theme install botiga  --allow-root
    wp theme install express-store --activate  --allow-root
    wp plugin install woocommerce --activate --allow-root
    chown -R www-data:www-data /var/www/$domain
}

function config()
{
    # config mariadb
    systemctl restart mariadb
    dbkey=`echo "${domain}" | sed -e "s/\./_/g"`
    dbname=${dbkey}
    dbuser=${dbkey}
    # dbpass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    dbpass='admin@qwe123'
    mysql -u root <<EOF
DROP user IF EXISTS ${dbuser};
CREATE DATABASE IF NOT EXISTS $dbname default charset utf8mb4;
CREATE USER ${dbuser}@'%' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON ${dbname}.* to ${dbuser}@'%';
FLUSH PRIVILEGES;
EOF

    # config wordpress
    cd /var/www/$domain


    # config nginx

    cat > /etc/nginx/sites-available/${domain}<<-EOF
server {
        server_name $domain;

        root /var/www/$domain;
        index index.html index.htm index.php;
        client_max_body_size 512m;

        location / {
          try_files \$uri \$uri/ @rewrites;
        }
        location @rewrites {
          rewrite ^(.+)$ /index.php last;
        }

        location ~ \.php$ {
	  proxy_set_header  Host  www.honestfulphilment.com;
	  include snippets/fastcgi-php.conf;
	  fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        }
    listen 80;
}
EOF
    ln -s /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled/${domain}
    systemctl restart php7.4-fpm mariadb nginx 
}


function buildSsl(){
    echo "WordPress Core SSL"
    apt install certbot python3-certbot-nginx -y
    certbot -n -m xiezhouyan@gmail.com -d $domain --agree-tos  --nginx 
    systemctl restart nginx
}
function output()
{
    echo "WordPress安装成功！"
    echo "==============================="
    echo -e "WordPress安装路径：${red}/var/www/${domain}${plain}"
    echo -e "WordPress数据库：${red}${dbname}${plain}"
    echo -e "WordPress数据库用户名：${red}${dbuser}${plain}"
    echo -e "WordPress数据库密码：${red}${dbpass}${plain}"
    echo -e "WordPress管理员邮箱：${red}wp_admin@163.com"
    echo -e "WordPress管理员密码：${red}admin@qwe!123"
    echo -e "博客访问地址：${red}http://${domain}${plain}"
    echo "==============================="
}

function main()
{
    checkSystem
    if [ ! -f "/opt/wp_install.txt" ];
        then
            preInstall
            installNginx
            installPHP
            installMysql
            echo "install" > /opt/wp_install.txt
    fi

    collect
    config
    buildSsl
    installWordPress
    output
}

main
