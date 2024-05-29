#!/bin/bash

LOGFILE="/var/log/setup_server.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
    echo "$1"
}

DOMAIN=$1
EMAIL=$2
WILDCARD=$3

log "Script started"
log "Domain: $DOMAIN"
log "Email: $EMAIL"
log "Wildcard: $WILDCARD"

log "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

log "Installing Apache2..."
sudo apt install apache2 -y

log "Configuring Apache to listen on port 8080..."
sudo sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
sudo sed -i 's/<VirtualHost *:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf

log "Enabling and starting Apache2 service..."
sudo systemctl enable apache2
sudo systemctl restart apache2

log "Installing MySQL Server..."
sudo apt install mysql-server -y

log "Securing MySQL installation..."
sudo mysql_secure_installation <<EOF

y
n
y
y
y
y
EOF

log "Installing PHP 8.3 and necessary modules..."
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.3 php8.3-fpm php8.3-mysql libapache2-mod-php8.3 -y

log "Configuring PHP..."
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.3-fpm

log "Restarting Apache2 to apply PHP configuration..."
sudo systemctl restart apache2

log "Installing Nginx..."
sudo apt install nginx -y

log "Installing Certbot for Let's Encrypt..."
sudo apt install certbot python3-certbot-nginx -y

WEB_ROOT="/var/www/$DOMAIN"
log "Creating web root directory at $WEB_ROOT..."
sudo mkdir -p $WEB_ROOT
sudo chown -R www-data:www-data $WEB_ROOT
sudo chmod -R 755 /var/www

log "Downloading and setting up WordPress..."
wget https://wordpress.org/latest.tar.gz -P /tmp
tar -xzf /tmp/latest.tar.gz -C /tmp
sudo cp -r /tmp/wordpress/* $WEB_ROOT
sudo chown -R www-data:www-data $WEB_ROOT

log "Creating wp-config.php..."
cp $WEB_ROOT/wp-config-sample.php $WEB_ROOT/wp-config.php

log "Generating random database credentials..."
DB_NAME="wp_$(openssl rand -hex 3)_$(echo $DOMAIN | tr -d '.')"
DB_USER="wp_user_$(openssl rand -hex 3)"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9@#$%^&*()_+-=' | head -c 16)
DB_HOST="localhost"

log "Database Name: $DB_NAME"
log "Database User: $DB_USER"
log "Database Password: $DB_PASS"

sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

log "Enabling secure wp-admin..."
sed -i "/<?php/a /** Force SSL for wp-admin **/\ndefine('FORCE_SSL_ADMIN', true);\nif (\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {\n    \$_SERVER['HTTPS'] = 'on';\n}\n" $WEB_ROOT/wp-config.php

sed -i "s/database_name_here/$DB_NAME/" $WEB_ROOT/wp-config.php
sed -i "s/username_here/$DB_USER/" $WEB_ROOT/wp-config.php
sed -i "s/password_here/$DB_PASS/" $WEB_ROOT/wp-config.php
sed -i "s/localhost/$DB_HOST/" $WEB_ROOT/wp-config.php

log "Creating sample index.php file..."
echo "<?php phpinfo(); ?>" | sudo tee $WEB_ROOT/index.php

log "Configuring Apache to serve from $WEB_ROOT..."
cat <<EOL | sudo tee /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:8080>
    ServerAdmin webmaster@localhost
    ServerName $DOMAIN
    DocumentRoot $WEB_ROOT
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

log "Enabling new site configuration..."
sudo a2ensite $DOMAIN.conf

log "Disabling default site configuration..."
sudo a2dissite 000-default.conf

log "Restarting Apache2 to apply the new configuration..."
sudo systemctl restart apache2

if [ "$WILDCARD" == "yes" ]; then
    log "Obtaining wildcard SSL certificate from Let's Encrypt..."
    sudo certbot certonly --manual --preferred-challenges=dns --email "$EMAIL" --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d "$DOMAIN" -d "*.$DOMAIN"
else
    log "Obtaining SSL certificate from Let's Encrypt..."
    sudo certbot --nginx -d "$DOMAIN" --redirect --email "$EMAIL" --agree-tos --non-interactive
fi

log "Configuring Nginx as a reverse proxy with SSL..."
cat <<EOL | sudo tee /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

log "Enabling new Nginx site configuration..."
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

log "Removing default Nginx site configuration..."
sudo rm /etc/nginx/sites-enabled/default

log "Restarting Nginx to apply the new configuration..."
sudo systemctl restart nginx

log "Installing UFW (Uncomplicated Firewall)..."
sudo apt install ufw -y

log "Allowing OpenSSH through UFW..."
sudo ufw allow OpenSSH

log "Allowing Nginx Full (HTTP and HTTPS) through UFW..."
sudo ufw allow 'Nginx Full'

log "Enabling UFW..."
sudo ufw enable

log "Installation and configuration complete!"
