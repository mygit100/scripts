#!/bin/bash
# docker-guacamole.sh

# Exit immediately if a command exits with a non-zero status.
#set -e

# Function to install missing packages
echo "Installing missing packages"
install_missing_package() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        echo "$package is missing. Installing..."
        sudo apt update
        sudo apt install -y "$package"
    fi
}

# Check and install missing applications
install_missing_package docker
install_missing_package docker-compose
install_missing_package openssl

# Ensure Docker is running
sudo systemctl start docker
sudo systemctl enable docker

# Set the base directory for Docker and Guacamole
BASE_DIR="$HOME/docker/guacamole"

# Create necessary directories if they don't exist
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# Create .env file with PostgreSQL credentials
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat << EOF > .env
POSTGRES_PASSWORD=$(openssl rand -base64 12)
POSTGRES_USER=sqldata
EOF
fi

# Load environment variables
source .env

# Create docker-compose.yml file if it doesn't exist
if [ ! -f docker-compose.yml ]; then
    echo "Creating docker-compose.yml..."
    cat << EOF > docker-compose.yml
version: "3.8"

services:
  guacamole-postgres:
    container_name: guacamole-postgres
    image: postgres:latest
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - guacamole-postgres-data:/var/lib/postgresql/data
    networks:
      - guacamole-network
    restart: always

  guacamole-guacd:
    container_name: guacamole-guacd
    image: guacamole/guacd:latest
    networks:
      - guacamole-network
    restart: always

  guacamole-client:
    container_name: guacamole-client
    image: guacamole/guacamole:latest
    environment:
      POSTGRESQL_DATABASE: guacamole_db
      POSTGRESQL_USER: \${POSTGRES_USER}
      POSTGRESQL_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRESQL_HOSTNAME: guacamole-postgres
      GUACD_HOSTNAME: guacamole-guacd
      GUACD_PORT: 4822
      TOTP_ENABLED: "true"
    ports:
      - "8080:8080"
    networks:
      - guacamole-network
    depends_on:
      - guacamole-postgres
      - guacamole-guacd
    restart: always

networks:
  guacamole-network:
    driver: bridge

volumes:
  guacamole-postgres-data:
    driver: local
EOF
fi

# Start the services
docker-compose up -d

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 15

# Check if the database has already been initialized
echo "Check if the database has already been initialized"
if ! docker exec guacamole-postgres psql -U postgres -d guacamole_db -c '\q' 2>/dev/null; then
    echo "Setting up the database..."

    # Create database and user
    docker exec -i guacamole-postgres psql -U postgres -d postgres << EOF
CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
CREATE DATABASE guacamole_db OWNER $POSTGRES_USER;
GRANT ALL ON DATABASE guacamole_db TO $POSTGRES_USER;
EOF

    # Initialize the database schema
    echo "Initialize the database schema"
    
    docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > initdb.sql
    docker cp initdb.sql guacamole-postgres:/
    docker exec -i guacamole-postgres psql -U $POSTGRES_USER -d guacamole_db -f /initdb.sql
fi

# Wait for everything to setup
echo "Pause for 15 seconds..."
sleep 15

# Restart the services to apply changes
echo "Restart the services to apply changes"
docker-compose down
docker-compose up -d

echo "Guacamole has been set up and is running on http://$(hostname -I | awk '{print $1}'):8080/guacamole/"
echo "Please check the .env file in ${BASE_DIR} for the database credentials."
echo "Default Guacamole credentials are guacadmin/guacadmin. Please change them after first login."
