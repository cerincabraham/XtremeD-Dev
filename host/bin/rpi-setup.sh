#!/bin/bash

export portno=9091
# currently set to 9091. Needs to be updated if the port config changes.
# Installers will also need to double check and update this if the port no changes between builds.
export newpassword=xtreme4630
# *** IMPORTANT NOTE *** declaring this as a variable in an open source project is totally insecure!
# Ideally the password should be changed offline, and this repo should never be updated to match that.
# but it's still better than sending out the hardware with the default pi user and password unchanged. Obviously.
export repo="cerincabraham/XtremeD-Dev"

#require SU
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

function checkInstalled {
return $(dpkg-query -W -f='${Status}\n' $1 | head -n1 | awk '{print $3;}' | grep -q '^installed$')
}

# DO FOR ALL
echo "Getting updates and installing utilities"
apt-get update
apt-get -y upgrade
apt-get -y install imagemagick rpi-chromium-mods dos2unix curl librxtx-java fbi git rsync rpi-update matchbox-window-manager uzbl xinit nodm Xorg unclutter feh jq tint2 wmctrl lxterminal
apt-get -fy install

# Check if a few of our packages installed. If it hasn't, FAIL OUT and do not progress further into the setup script.
echo "Verifying installs"
checkInstalled dos2unix || exit;
checkInstalled matchbox-window-manager || exit;
checkInstalled fbi || exit;

# we could potentially test for installation of all the needed applications, but I don't think it's really necessary

if [ -e photonic-repo ]; then
	rm -rf photonic-repo
fi
git clone https://github.com/${repo}.git photonic-repo
rpi-update

if [ "$build" != "4ktouch" ]; then
		echo "update photonic"
		# would prefer to call this to update to a particular version,
		# but the auto-update in start.sh will flatten any changes we make in the next section
		# so doing this first.
		chmod +x photonic-repo/host/bin/*.sh
		dos2unix photonic-repo/host/bin/*.sh
		if [ -e "/opt/cwh/stop.sh" ]
			then
				# kill the old version of photonic using its stop.sh script
				/opt/cwh/stop.sh
		fi
		# launch the Photocentric rather than area515 version of start.sh - ensures using Photocentric branch
		photonic-repo/host/bin/start.sh
		dos2unix /opt/cwh/*.sh
fi


# redirect boot terminal output not to screen
echo "removing pi branding"
# ensure the pi always boots to console
raspi-config nonint do_boot_behaviour B2
# we can't remove everything as some is baked into the pi's firmware, but this gives a realistic amount.
if [ ! -e "/boot/cmdline.old" ]; then
	mv /boot/cmdline.txt /boot/cmdline.old 
	echo -n "loglevel=3 logo.nologo " > /boot/cmdline.txt
	cat /boot/cmdline.old >> /boot/cmdline.txt 
	sed -i "s/tty1/tty/g" /boot/cmdline.txt
else
	echo "already complete!"
fi

echo "installing common files"
rsync -avr photonic-repo/host/common/ /
cp photonic-repo/host/os/Linux/armv61/pdp /opt/cwh/os/Linux/armv61/pdp #copy display manager for screen + curing screen printers
cp photonic-repo/host/resourcesnew/printflow/holdingpage.html /home/pi/holdingpage.html #copy holdingpage for fallback
#install splash screen
if [ -e /etc/splash.png ]; then
	chown root /etc/splash.png
	chmod 777 /etc/splash.png
fi
if [ -e /etc/updating.png ]; then
	chown root /etc/updating.png
	chmod 777 /etc/updating.png
fi

if [ -e /etc/init.d/aasplashscreen ]; then
	chmod a+x /etc/init.d/aasplashscreen
	insserv /etc/init.d/aasplashscreen
fi

echo "disabling screen power down"
if [ -e "/etc/default/nodm" ]
	then
		sed -i "s/=false/=true/g" /etc/default/nodm
		sed -i "s/root/pi/g" /etc/default/nodm
	else
		echo "nodm doesn't exist"
fi
# this already happens once due to our rsync of an X11 config, but why not just make sure, eh?

echo "Working on per printer settings..."
echo \# Photocentric mods >> /boot/config.txt


	# Touchscreen pis only
	echo "Modifying config files for touchscreen"
	if grep -Fxq "disable_splash" /boot/config.txt
	then
		echo "already done!"
	else
		echo disable_splash=1 >> /boot/config.txt
		echo avoid_warnings=1 >> /boot/config.txt
	fi
	echo "installing kiosk browser"
	# since this isn't on standard apt-get sources, i'm keeping this as an alternative way to source kweb
	###wget http://steinerdatenbank.de/software/kweb-1.7.4.tar.gz
	###tar -xzf kweb-1.7.4.tar.gz
	###cd kweb-1.7.4
	###./debinstall
	###rm -rf kweb-1.7.4
	if grep -Fxq "chromium" /etc/apt/sources.list
	then
		echo "already done!"
	else
		wget -qO - http://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
		echo "deb http://dl.bintray.com/kusti8/chromium-rpi jessie main" | tee -a /etc/apt/sources.list
		apt-get update
		yes Y | apt-get install -y kweb
		apt-get -fy install
	fi
	
	touch /home/pi/.xsession
	echo "Setting up kiosk-only mode"
	if grep -Fxq "kweb" /home/pi/.xsession
	then
		echo "already done!"
	else
		
		echo \#\!/bin/bash > /home/pi/.xsession
		echo xset s off >> /home/pi/.xsession
		echo xset -dpms >> /home/pi/.xsession
		echo xset s noblank >> /home/pi/.xsession
	
	
		if [ "$build" == "4ktouch" ]; then
			export target=4kscreen.local
		else
			export target=localhost
		fi


		echo unclutter -jitter 1 -idle 0.2 -noevents -root \& feh -NY --bg /etc/splash.png /etc/ \& exec matchbox-window-manager -use_titlebar no \& >> /home/pi/.xsession
		echo while true\; do >> /home/pi/.xsession
	
		echo -e "\tif curl -fI http://${target}:${portno}/printflow/images/pixel.png" >> /home/pi/.xsession			
		echo -e "\t\tthen" >> /home/pi/.xsession
		echo -e "\t\t\t#uzbl -u /home/pi/holdingpage.html?target=http://${target}:${portno}/printflow -c /home/pi/uzbl.conf &;" >> /home/pi/.xsession
		echo -e "\t\t\tkweb -KEJ http://${target}:${portno}/printflow ;" >> /home/pi/.xsession		
		echo -e "\tfi" >> /home/pi/.xsession

		#echo exec matchbox-window-manager -use_titlebar no\; >> /home/pi/.xsession
		echo -e "\tsleep 2s;" >> /home/pi/.xsession
		echo done >> /home/pi/.xsession
		fi
	
		if [ ! -e "/home/pi/uzbl.conf" ]; then
			#keeping this as a fallback for kweb as sometimes kweb servers can be offline
			touch /home/pi/uzbl.conf
			echo set show_status=0 >> /home/pi/uzbl.conf
			echo set geometry=maximized >> /home/pi/uzbl.conf
		fi
			




		newhost="xtreme-d"

# Change hostname
# left this 'til last for good reasons. Keep it last now.
export hostn=$(cat /etc/hostname)
echo "Existing hostname is $hostn, changing to $newhost"
sed -i "s/${hostn}/${newhost}/g" /etc/hosts
sed -i "s/${hostn}/${newhost}/g" /etc/hostname
echo "Your new hostname is $newhost, accessible from $newhost.local"

echo "changing password"
echo "pi:${newpassword}" | chpasswd
echo "password updated!"
#if you haven't already, re-read the big important note at the top!

rm -rf photonic-repo
rm printerprofile.json

# make auto USB mount to work
udevadm control --reload-rules

apt-get clean
reboot
