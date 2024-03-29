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
    apt-get update -y
    apt install software-properties-common -y
    add-apt-repository ppa:ondrej/php -y
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
    apt-get install php7.4 php7.4-fpm php7.4-mysql php7.4-cli php7.4-xml pp7.4-xmlrpc php7.4-curl php7.4-mcrypt php7.4-mbstring -y 
    systemctl restart php7.4-fpm.service
}

function installMysql()
{
    apt-get install mysql-server -y;
    systemctl restart mysql.
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
    rm -rf /var/www/${domain}
    mkdir -p /var/www/${domain};
    cd /var/www/${domain};
    wp core download --version=6.2.3 --allow-root
    wp config create --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbhost=127.0.0.1 --dbprefix=wp --allow-root
    wp config set ALLOW_UNFILTERED_UPLOADS true --raw --allow-root
    wp core install --url=$domain --title=$domain --admin_user=admin --admin_password=admin@qwe!123 --admin_email=wp_admin@163.com --allow-root 
    wp plugin install https://downloads.wordpress.org/plugin/woocommerce.7.7.2.zip --activate --allow-root 
    wp plugin install woocommerce-paypal-payments --activate --allow-root 
    wp theme install botiga  --activate --allow-root
    wp rewrite structure '/%postname%/' --allow-root
    wp eval '
	global $wpdb;
	echo $wpdb->insert(
	  $wpdb->prefix . "woocommerce_api_keys",
	  array(
	    "user_id" => 1,
	    "description" => "Client",
	    "permissions" => "read_write",
	    "consumer_key"=> wc_api_hash("ck_a6dcc64339b4a95edc680519c1b83d954a3319c9"),
	    "consumer_secret" => "cs_a4b514e95c5e415a92d13aace50c4e368f04498f",
	    "truncated_key" => substr("ck_a6dcc64339b4a95edc680519c1b83d954a3319c9", -7)
	  )
	);' --allow-root
    chown -R www-data:www-data /var/www/$domain
}

function config()
{
    # config mysql
    systemctl restart mysql
    dbkey=`echo "${domain}" | sed -e "s/\./_/g"`
    dbname=${dbkey}
    dbuser=${dbkey}
    # dbpass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    dbpass='admin@qwe123'
    mysql -u root <<EOF
DROP database IF EXISTS $dbname;
DROP user IF EXISTS ${dbuser};
CREATE DATABASE IF NOT EXISTS $dbname default charset utf8mb4;
CREATE USER ${dbuser}@'%' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON ${dbname}.* to ${dbuser}@'%';
FLUSH PRIVILEGES;
EOF

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
    rm -rf /etc/nginx/sites-enabled/${domain}
    ln -s /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled/${domain}
    systemctl restart php7.4-fpm mysql nginx 
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
	    installMysql
            installPHP
            echo "install" > /opt/wp_install.txt
    fi

    collect
    config
    buildSsl
    installWordPress
    output
}

main
