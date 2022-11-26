#!/bin/sh
echo "Custom userdata started" >>/status.log
sleep 30
# Create systemd startup script
fname=/etc/systemd/system/startupscript.service
chmod 757 /usr/bin/startupscript.sh
echo '[Unit]'>$fname
echo 'Description=Startup script.'>>$fname
echo 'After=cloud-init.service'>>$fnameecho ''>>$fname
echo '[Service]'>>$fname
echo 'Type=simple'>>$fname
echo 'User=root'>>$fname
echo 'ExecStart=/bin/bash /usr/bin/startupscript.sh'>>$fname
echo ''>>$fname
echo '[Install]'>>$fname
echo 'WantedBy=multi-user.target'>>$fname

chmod 755 $fname
systemctl daemon-reload
systemctl enable startupscript.service
echo "Performing yum update, will reboot when finished" >>/status.log
yum update -y
echo "Custom userdata finished" >>/status.log
reboot
