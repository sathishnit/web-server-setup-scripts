#!/bin/bash

LOGFILE="/var/log/setup_server.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
    echo "$1"
}

log "Script started"

DOMAIN=$1
EMAIL=$2
WILDCARD=$3

log "Domain: $DOMAIN"
log "Email: $EMAIL"
log "Wildcard: $WILDCARD"

# Update and upgrade the system
log "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

# Install Apache2
log "Installing Apache2..."
sudo apt install apache2 -y

# Enable and start Apache2 service
log "Enabling and starting Apache2 service..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Install MySQL Server
log "Installing MySQL Server..."
sudo apt install mysql-server -y

# Secure MySQL installation
log "Securing MySQL installation..."
sudo mysql_secure_installation

# Install PHP 8.3 and necessary modules
log "Installing PHP 8.3 and necessary modules..."
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.3 php8.3-fpm php8.3-mysql libapache2-mod-php8.3 -y

# Configure PHP
log "Configuring PHP..."
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.3-fpm

# Restart Apache2 to apply PHP configuration
log "Restarting Apache2 to apply PHP configuration..."
sudo systemctl restart apache2

# Install Nginx
log "Installing Nginx..."
sudo apt install nginx -y

# Install Certbot for Let's Encrypt
log "Installing Certbot for Let's Encrypt..."
sudo apt install certbot python3-certbot-nginx -y

# Create web root directory
WEB_ROOT="/var/www/$DOMAIN"
log "Creating web root directory at $WEB_ROOT..."
sudo mkdir -p $WEB_ROOT
sudo chown -R $USER:$USER $WEB_ROOT
sudo chmod -R 755 /var/www

# Create a sample index.php file
log "Creating sample index.php file..."
echo "<?php phpinfo(); ?>" | sudo tee $WEB_ROOT/index.php

# Create a new Apache configuration file for the domain
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

# Enable the new site configuration
log "Enabling new site configuration..."
sudo a2ensite $DOMAIN.conf

# Disable the default site configuration
log "Disabling default site configuration..."
sudo a2dissite 000-default.conf

# Restart Apache2 to apply the new configuration
log "Restarting Apache2 to apply the new configuration..."
sudo systemctl restart apache2

# Obtain SSL certificate from Let's Encrypt
if [ "$WILDCARD" == "yes" ]; then
    log "Obtaining wildcard SSL certificate from Let's Encrypt..."
    sudo certbot certonly --manual --preferred-challenges=dns --email "$EMAIL" --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d "$DOMAIN" -d "*.$DOMAIN"
else
    log "Obtaining SSL certificate from Let's Encrypt..."
    sudo certbot --nginx -d "$DOMAIN" --redirect --email "$EMAIL" --agree-tos --non-interactive
fi

# Configure Nginx as a reverse proxy with SSL
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

# Enable the new Nginx site configuration
log "Enabling new Nginx site configuration..."
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Remove the default Nginx site configuration
log "Removing default Nginx site configuration..."
sudo rm /etc/nginx/sites-enabled/default

# Restart Nginx to apply the new configuration
log "Restarting Nginx to apply the new configuration..."
sudo systemctl restart nginx

# Install UFW
log "Installing UFW (Uncomplicated Firewall)..."
sudo apt install ufw -y

# Allow OpenSSH
log "Allowing OpenSSH through UFW..."
sudo ufw allow OpenSSH

# Allow Nginx Full (HTTP and HTTPS)
log "Allowing Nginx Full (HTTP and HTTPS) through UFW..."
sudo ufw allow 'Nginx Full'

# Enable UFW
log "Enabling UFW..."
sudo ufw enable

# All done
log "Installation and configuration complete!"
