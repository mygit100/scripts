#!/bin/bash

# Check if script is run as root
#if [ "$(id -u)" -ne 0 ]; then
#    echo "Please run this script as root."
#   exit 1
#fi

# save login user and user path to variables
myusername=$(logname)
mypath=$(eval echo ~$(logname))

# Uninstall previous Docker installations
sudo apt remove -y docker docker-engine docker.io containerd runc

# Update package list
sudo apt update

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
sudo curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository  *** only needed for arm (RP) installs 
#echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Add Docker Compose repository  *** only needed for arm (RP) installs
#echo "deb [arch=arm64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker-compose.list > /dev/null

# Update package list again to include Docker and Docker Compose repositories
sudo apt update

# Install Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
sudo apt install -y docker-compose

# Add current user to Docker group
sudo usermod -aG docker $myusername

# Check if /etc/docker folder exists
if [ ! -d "/etc/docker" ]; then
    sudo mkdir -p /etc/docker
fi

# Docker Log Rotation
# Download daemon.json from the given URL and overwrite if it exists
sudo wget -O /etc/docker/daemon.json https://raw.githubusercontent.com/mygit100/scripts/main/daemon.json

# Configure Portainer folder in current user's home directory
mkdir -p $mypath/docker/portainer_data

# Create and start Portainer container
sudo docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock -v $mypath/docker/portainer_data:/data portainer/portainer-ce:latest


# running local do not need to open ports

# Check if UFW (Uncomplicated Firewall) is installed
#if ! command -v ufw &> /dev/null; then
#    echo "UFW is not installed. Installing UFW..."
#    apt install -y ufw
#fi

# Enable firewall 
#ufw enable

# Allow access to Portainer remotely
#ufw allow 9000/tcp

# Allow access to SSH
#ufw allow ssh

# Reload firewall rules
#ufw reload
