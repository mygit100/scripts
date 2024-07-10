#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
GUAC_VERSION="1.5.0"
MYSQL_USER="guacamole_user"
MYSQL_PASSWORD="your_password"
DB_NAME="guacamole_db"
MYSQL_ROOT_PASSWORD="your_new_mysql_root_password"

# Update and upgrade the system
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin libossp-uuid-dev \
libavcodec-dev libavformat-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev \
libtelnet-dev libvncserver-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev wget

# Install OpenJDK 17
sudo apt install -y openjdk-17-jre-headless

# Install MariaDB
sudo apt install -y mariadb-server

# Clean up any existing Tomcat installation
sudo systemctl stop tomcat || true
sudo systemctl disable tomcat || true
sudo rm -rf /opt/tomcat
sudo rm -rf /opt/apache-tomcat-9.0.64

# Install Tomcat 9 manually
cd /tmp
wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.64/bin/apache-tomcat-9.0.64.tar.gz
sudo tar -xzf apache-tomcat-9.0.64.tar.gz -C /opt
sudo mv /opt/apache-tomcat-9.0.64 /opt/tomcat

# Create Tomcat service
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=root
Group=root

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd daemon to apply the new service
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

# Download and build Guacamole server
cd /tmp
wget https://archive.apache.org/dist/guacamole/1.5.0/source/guacamole-server-1.5.0.tar.gz
tar -xzf guacamole-server-1.5.0.tar.gz
cd guacamole-server-1.5.0

# Patch the source code to fix const qualifier issues
sed -i 's/const AVOutputFormat/AVOutputFormat/' src/guacenc/video.c
sed -i 's/const AVCodec/AVCodec/' src/guacenc/video.c

# Adjust compiler flags to ignore discarded-qualifiers warnings
export CFLAGS="-Wno-error=discarded-qualifiers"

# Compile and install Guacamole server
./configure --with-init-dir=/etc/init.d
make
sudo make install
sudo ldconfig

# Create guacd service
sudo tee /etc/systemd/system/guacd.service > /dev/null <<EOF
[Unit]
Description=Guacamole proxy daemon (guacd)
After=network.target

[Service]
ExecStart=/usr/local/sbin/guacd -b 127.0.0.1 -l 4822

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd daemon to apply the new service
sudo systemctl daemon-reload
sudo systemctl start guacd
sudo systemctl enable guacd

# Download Guacamole client and extensions
cd /tmp
wget https://archive.apache.org/dist/guacamole/1.5.0/binary/guacamole-1.5.0.war
wget https://archive.apache.org/dist/guacamole/1.5.0/binary/guacamole-auth-totp-1.5.0.tar.gz
wget https://archive.apache.org/dist/guacamole/1.5.0/binary/guacamole-auth-jdbc-1.5.0.tar.gz
tar -xzf guacamole-auth-totp-1.5.0.tar.gz
tar -xzf guacamole-auth-jdbc-1.5.0.tar.gz

# Move files to appropriate locations
sudo mv guacamole-1.5.0.war /opt/tomcat/webapps/guacamole.war
sudo mkdir -p /etc/guacamole/extensions
sudo cp guacamole-auth-totp-1.5.0/guacamole-auth-totp-1.5.0.jar /etc/guacamole/extensions/
sudo cp guacamole-auth-jdbc-1.5.0/mysql/guacamole-auth-jdbc-mysql-1.5.0.jar /etc/guacamole/extensions/

# Secure MariaDB installation and configure Guacamole database
sudo mysql_secure_installation <<EOF

y
y
${MYSQL_ROOT_PASSWORD}
${MYSQL_ROOT_PASSWORD}
y
y
y
y
EOF

# Log into MariaDB and set up database and user if they don't exist
sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT SELECT,INSERT,UPDATE,DELETE ON ${DB_NAME}.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Initialize Guacamole database schema if it's a new installation
if [[ ! -f /etc/guacamole/guacamole.properties ]]; then
    cd guacamole-auth-jdbc-1.5.0/mysql/schema
    cat *.sql | sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} ${DB_NAME}
fi

# Configure Guacamole
sudo mkdir -p /etc/guacamole
sudo tee /etc/guacamole/guacamole.properties > /dev/null <<EOF
guacd-hostname: localhost
guacd-port: 4822
auth-provider: net.sourceforge.guacamole.net.auth.mysql.MySQLAuthenticationProvider
mysql-hostname: localhost
mysql-port: 3306
mysql-database: ${DB_NAME}
mysql-username: ${MYSQL_USER}
mysql-password: ${MYSQL_PASSWORD}
EOF

# Create symbolic link
sudo ln -s /etc/guacamole /opt/tomcat/.guacamole

# Restart Tomcat
sudo systemctl restart tomcat

# Output success message
echo "Apache Guacamole installation is complete."
echo "You can access Guacamole at http://<your-raspberry-pi-ip>:8080/guacamole"
