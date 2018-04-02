#!/bin/bash

owner_mail="gubi.ale@iod.io"

root=/var/www
webserver=$1
server_name=$2
webroot=$root/$server_name
SERVER_IP=`hostname -I | cut -f1 -d' '`

homepage="
<html>
    <head>
        <title>Welcome to ${server_name}!</title>
    </head>
    <body>
        <h1>Success!</h1>
        <p>The ${server_name} server block is working!</p>
    </body>
</html>
"
info="<?php phpinfo(); ?>"
apache_server_config="
<VirtualHost ${server_name}:80>
        ServerName ${server_name}
        ServerAdmin webmaster@${server_name}
        DocumentRoot ${webroot}

        ErrorLog \${APACHE_LOG_DIR}/${server_name}.error.log
        CustomLog \${APACHE_LOG_DIR}/${server_name}.access.log combined

        # Root
        <Directory ${webroot}>
                Options Indexes FollowSymLinks
                AllowOverride All
        </Directory>
</VirtualHost>
"
apache_server_ssl_config="
<IfModule mod_ssl.c>
    <VirtualHost ${server_name}:443>
            ServerName ${server_name}
            ServerAdmin webmaster@${server_name}
            DocumentRoot ${webroot}

            ErrorLog \${APACHE_LOG_DIR}/${server_name}.ssl.error.log
            CustomLog \${APACHE_LOG_DIR}/${server_name}.ssl.access.log combined

            # SSL
            SSLCertificateFile /etc/letsencrypt/live/${server_name}/fullchain.pem
            SSLCertificateKeyFile /etc/letsencrypt/live/${server_name}/privkey.pem
            Include /etc/letsencrypt/options-ssl-apache.conf

            # Root
            <Directory ${webroot}>
                    Options Indexes FollowSymLinks
                    AllowOverride All
            </Directory>
    </VirtualHost>
</IfModule>
"
nginx_server_config="
server {
        listen 80;
        server_name ${server_name};
        root ${webroot};
        index index.php;

        location / {
                try_files \$uri \$uri/ =404;
        }
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php7.1-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
        location ~ /\.ht {
            deny all;
        }
        location ~ /.well-known {
            allow all;
        }
}
"
cron_config="0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(3600))' && certbot -q renew"

# check if ENV are set
if [[ -z "${webserver}" ]]; then
    echo "No server configured!"
else
    if [[ -z "${server_name}" ]]; then
        echo "No domain configured!"
    else
        # Add PPA repositories:
        # - PHP 7.1 - ondrej/php
        # - Let's Encrypt - certbot/certbot
        if ! grep -q "^deb .*ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            add-apt-repository -y ppa:ondrej/php
        fi
        if ! grep -q "^deb .*certbot/certbot" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            add-apt-repository -y ppa:certbot/certbot
        fi
        # Update all
        apt update -y
        apt upgrade -y
        # Install:
        # - NGINX Server
        # - Apache Server
        # - cURL
        # - PHP 7.1
        if [[ "${webserver}" == "nginx" ]]; then
            apt install -y nginx
            apt install -y python-certbot-nginx
        fi
        if [[ "${webserver}" == "apache" ]]; then
            apt install -y apache2
            apt install -y python-certbot-apache
        fi
        apt install -y curl software-properties-common
        apt install -y php7.1-fpm php7.1-cli php7.1-common php7.1-json php7.1-opcache php7.1-mysql php7.1-mbstring php7.1-mcrypt php7.1-zip php7.1-fpm php7.1-ldap php7.1-tidy php7.1-recode php7.1-curl

        if [[ "${webserver}" == "apache" ]]; then
            a2dissite   000-default.conf
        fi

        # Allow NGINX HTTP firewall
        ufw enable
        ufw allow ssh
        if [[ "${webserver}" == "nginx" ]]; then
            ufw allow 'Nginx Full'
        fi
        if [[ "${webserver}" == "apache" ]]; then
            ufw allow 'Apache Full'
        fi
        ufw status

        # Create Let's Encrypt certificate
        if [[ "${webserver}" == "nginx" ]]; then
            certbot --nginx -d $server_name
        fi
        if [[ "${webserver}" == "apache" ]]; then
            certbot --apache -d $server_name
        fi
        # certbot renew --dry-run


        # Display the server status
        if [[ "${webserver}" == "nginx" ]]; then
            service nginx status
        fi
        if [[ "${webserver}" == "apache" ]]; then
            service apache2 status
        fi

        # Modify permissions on webserver root
        chmod -R 755 $root
        # Create the directory for the website
        mkdir -p $webroot
        # Change owner
        chown -R www-data $root
        echo "directory $webroot created"

        # Remove the default `html` folder
        rm -rf $root/html

        # Create the index.php file
        echo "$homepage" > $webroot/index.php
        # Create the info-php file
        echo "$info" > $webroot/info.php

        # WEBSERVER
        if [[ "${webserver}" == "nginx" ]]; then
            sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
            sed -i "s/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g" /etc/php/7.1/fpm/php.ini

            Remove default and previous configurations
            rm /etc/nginx/sites-available/default
            rm /etc/nginx/sites-enabled/default
            rm /etc/nginx/sites-available/$server_name
            rm /etc/nginx/sites-enabled/$server_name
        fi
        if [[ "${webserver}" == "apache" ]]; then
            a2dissite 000-default.conf
        fi

        # Configure the webserver
        if [[ "${webserver}" == "nginx" ]]; then
            echo "$nginx_server_config" > /etc/nginx/sites-available/$server_name
            # Enable the webserver
            ln -s /etc/nginx/sites-available/$server_name /etc/nginx/sites-enabled/
        fi
        if [[ "${webserver}" == "apache" ]]; then
            echo "$apache_server_config" > /etc/apache2/sites-available/$server_name.conf
            echo "$apache_server_ssl_config" > /etc/apache2/sites-available/$server_name-le.conf
            # Enable the webserver
            sudo a2enmod ssl
            a2ensite $server_name.conf $server_name-le.conf
        fi

        # Check if all is ok and restart the webserver
        if [[ "${webserver}" == "nginx" ]]; then
            nginx -t
            service nginx restart
        fi
        if [[ "${webserver}" == "apache" ]]; then
            service apache2 restart
        fi

        # Install the crontab to renew the certificate
        echo $cron_config >> /etc/cron.d/certbot

        echo "Done."
        echo "See https://www.ssllabs.com/ssltest/analyze.html?d=$server_name for the SSL certificate status"
    fi
fi
exit
