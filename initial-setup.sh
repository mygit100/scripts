#!/bin/bash
set -e  # Enable exit-on-error mode

# Update system
sudo apt-get update -y
sudo apt dist-upgrade -y
sudo apt-get upgrade -y

sudo apt autoremove -y

# Install tmux and VIM
sudo apt install tmux vim wget -y

# Set up history synchronization across all terminals
mkdir -p ~/scripts
cd ~/scripts
wget --no-check-certificate https://raw.githubusercontent.com/mygit100/scripts/main/sync-history.sh

# Add sync-history.sh to .bashrc
echo "source ~/scripts/sync-history.sh" >> ~/.bashrc

# Add date and time to command history
echo 'export HISTTIMEFORMAT="%F %T "' >> ~/.bashrc

# Set up VIM
wget --no-check-certificate -P ~/ https://raw.githubusercontent.com/mygit100/scripts/main/.vimrc

# Allow root and current user to use the same .vimrc settings
sudo ln -s /home/reverset/.vimrc /root/.vimrc
