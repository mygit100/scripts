#!/bin/bash
sudo echo

read -p "Enter remote username : " remotename
read -s -p "Enter $remotename password : " remotepw

echo $remotename
echo $remotepw


egrep "^$remotename" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
        echo "$remotename exists!"
        exit 1
else
        pass=$(perl -e 'print crypt($ARGV[0], "password")' $remotepw)
        sudo useradd -m -p "$pass" "$remotename"
        [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
fi

sudo apt update -y
sudo apt autoremove -y
sudo apt install tmux openssh-server -y 
sudo apt install xrdp -y

sudo usermod -a -G sudo $remotename
sudo usermod -a -G libvirt $remotename
sudo usermod -a -G kvm $remotename
