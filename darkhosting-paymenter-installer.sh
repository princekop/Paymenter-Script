#!/bin/bash

# Darkhosting Paymenter Installer
# Made by Nikhil

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

# Functions
function print_header() {
    clear
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}                                                                ${NC}"
    echo -e "${PURPLE}██████╗  █████╗ ██████╗ ██╗  ██╗██╗  ██╗ ██████╗ ███████╗████████╗██╗███╗   ██╗ ██████╗${NC}"
    echo -e "${PURPLE}██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██║████╗  ██║██╔════╝${NC}"
    echo -e "${PURPLE}██║  ██║███████║██████╔╝█████╔╝ ███████║██║   ██║███████╗   ██║   ██║██╔██╗ ██║██║  ███╗${NC}"
    echo -e "${PURPLE}██║  ██║██╔══██║██╔══██╗██╔═██╗ ██╔══██║██║   ██║╚════██║   ██║   ██║██║╚██╗██║██║   ██║${NC}"
    echo -e "${PURPLE}██████╔╝██║  ██║██║  ██║██║  ██╗██║  ██║╚██████╔╝███████║   ██║   ██║██║ ╚████║╚██████╔╝${NC}"
    echo -e "${PURPLE}╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝${NC}"
    echo -e "${PURPLE}                                                                ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${CYAN}                      🚀 Paymenter Installer 🚀                  ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

function print_step() {
    echo -e "\n${YELLOW}[$1/${TOTAL_STEPS}] ${GREEN}$2...${NC}"
}

function loading_animation() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " ${CYAN}[%c]${NC}  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function ask_details() {
    print_step 1 "Gathering information"
    echo -e "${GREEN}📝 Enter your domain name (e.g., example.com):${NC}"
    read -rp "Domain: " DOMAIN
    echo -e "${GREEN}🔐 Enter the database password for Paymenter:${NC}"
    read -srp "Database Password: " DB_PASSWORD
    echo ""
}

function install_dependencies() {
    print_step 2 "Installing dependencies"
    (
        apt update
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.11"
        apt update
        apt -y install php8.2 php8.2-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
        apt -y install certbot python3-certbot-nginx
    ) >/dev/null 2>&1 &
    loading_animation $!
    echo -e "${GREEN}✅ Dependencies installed successfully!${NC}"
}

function setup_paymenter() {
    print_step 3 "Setting up Paymenter"
    (
        mkdir -p /var/www/paymenter
        cd /var/www/paymenter
        curl -Lo paymenter.tar.gz https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz
        tar -xzvf paymenter.tar.gz
        chmod -R 755 storage/* bootstrap/cache/

        mysql -u root -e "CREATE DATABASE IF NOT EXISTS paymenter;"
        mysql -u root -e "DROP USER IF EXISTS 'paymenter'@'localhost';"
        mysql -u root -e "CREATE USER 'paymenter'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
        mysql -u root -e "GRANT ALL PRIVILEGES ON paymenter.* TO 'paymenter'@'localhost' WITH GRANT OPTION;"
        mysql -u root -e "FLUSH PRIVILEGES;"

        cp .env.example .env
        composer install --no-dev --optimize-autoloader
        php artisan key:generate --force
        php artisan storage:link

        sed -i "s/DB_DATABASE=.*/DB_DATABASE=paymenter/" .env
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=paymenter/" .env
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env

        php artisan migrate --force --seed
    ) >/dev/null 2>&1 &
    loading_animation $!
    echo -e "${GREEN}✅ Paymenter setup completed!${NC}"
}

function configure_nginx() {
    print_step 4 "Configuring Nginx and SSL"
    (
        cat <<EOL > /etc/nginx/sites-available/paymenter.conf
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/paymenter/public;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
EOL
        ln -sf /etc/nginx/sites-available/paymenter.conf /etc/nginx/sites-enabled/
        systemctl restart nginx
        certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}
        chown -R www-data:www-data /var/www/paymenter/*
    ) >/dev/null 2>&1 &
    loading_animation $!
    echo -e "${GREEN}✅ Nginx and SSL configured successfully!${NC}"
}

function configure_cron_and_worker() {
    print_step 5 "Setting up Cronjob and Queue Worker"
    (
        echo "* * * * * php /var/www/paymenter/artisan schedule:run >> /dev/null 2>&1" | sudo tee -a /etc/crontab >/dev/null

        cat <<EOL > /etc/systemd/system/paymenter.service
[Unit]
Description=Paymenter Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/paymenter/artisan queue:work
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL
        systemctl enable --now paymenter.service
    ) >/dev/null 2>&1 &
    loading_animation $!
    echo -e "${GREEN}✅ Cronjob and Queue Worker setup completed!${NC}"
}

function create_admin_user() {
    print_step 6 "Creating admin user"
    cd /var/www/paymenter
    php artisan p:user:create
    echo -e "${GREEN}✅ Admin user creation completed!${NC}"
}

function uninstall_paymenter() {
    print_step 1 "Removing Paymenter"
    (
        systemctl stop paymenter.service
        systemctl disable paymenter.service
        rm -f /etc/systemd/system/paymenter.service
        rm -f /etc/nginx/sites-enabled/paymenter.conf
        rm -f /etc/nginx/sites-available/paymenter.conf
        rm -rf /var/www/paymenter
        mysql -u root -e "DROP DATABASE paymenter;"
        mysql -u root -e "DROP USER 'paymenter'@'localhost';"
        systemctl restart nginx
    ) >/dev/null 2>&1 &
    loading_animation $!
    echo -e "${GREEN}✅ Paymenter has been successfully removed.${NC}"
}

function display_summary() {
    echo -e "\n${CYAN}================================================================${NC}"
    echo -e "${GREEN}🎉 Installation Complete! 🎉${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}🌐 Domain: ${WHITE}https://${DOMAIN}${NC}"
    echo -e "${CYAN}🗄️ Database Name: ${WHITE}paymenter${NC}"
    echo -e "${CYAN}👤 Database User: ${WHITE}paymenter${NC}"
    echo -e "${CYAN}🔑 Database Password: ${WHITE}${DB_PASSWORD}${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${CYAN}        Made with ❤️ by Nikhil for Darkhosting 2024         ${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

# Main Menu
TOTAL_STEPS=6
while true; do
    print_header
    echo -e "\n${GREEN}🚀 What would you like to do?${NC}"
    echo -e "${BLUE}1) 📥 Install Paymenter${NC}"
    echo -e "${RED}2) 🗑️ Uninstall Paymenter${NC}"
    echo -e "${CYAN}3) 🚪 Exit${NC}"
    read -rp "Choose an option [1-3]: " OPTION

    case $OPTION in
        1)
            ask_details
            install_dependencies
            setup_paymenter
            configure_nginx
            configure_cron_and_worker
            create_admin_user
            display_summary
            exit 0
            ;;
        2)
            uninstall_paymenter
            exit 0
            ;;
        3)
            echo -e "\n${BLUE}👋 Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}❌ Invalid option. Please try again.${NC}"
            sleep 2
            ;;
    esac
done
