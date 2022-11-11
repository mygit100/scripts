sudo apt update
sudo apt install tmux, openssh-server -y 
sudo apt install xrdp -y

# what name do you want to use

sudo adduser reverseme
sudo usermod -a -G reverset reverseme
sudo systemctl restart xrdp
