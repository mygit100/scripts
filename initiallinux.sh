sudo -i

read -p "Enter remote username : " remotename
read -s -p "Enter $remotename password : " remotepw
egrep "^$remotename" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
	echo "$remotename exists!"
	exit 1
else
	pass=$(perl -e 'print crypt($ARGV[0], "password")' $remotepw)
	useradd -m -p "$pass" "$remotename"
	[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
fi

apt update
apt autoremove
apt install tmux, openssh-server -y 
apt install xrdp -y

usermod -a -G sudo $remotename
usermod -a -G libvirt $remotename
usermod -a -G kvm $remotename

systemctl restart xrdp
