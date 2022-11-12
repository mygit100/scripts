sudo echo

read -p "What username would you like to use for remote connection? " remotename
read -p "Enter a password for remote user." remotepw

echo "Your remote credentials are 
echo "username - $remotename"
echo "password - $remotepw"

sudo apt update
sudo apt install tmux, openssh-server -y 
sudo apt install xrdp -y

sudo adduser $remotename
sudo usermod -a -G reverset $remotename
sudo systemctl restart xrdp
