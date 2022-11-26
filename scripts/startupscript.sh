#!/bin/bash
logfile="/status.log"
echo "Startup script started" >>$logfile
#Read in parameters
. ../parameters.sh

# Update Route53
# Get IP
ipaddr=$(ifconfig eth0 |grep "inet " |cut -d " " -f 10)

#Get the zone ID
#zone=$(aws route53 list-hosted-zones-by-name --query 'HostedZones[?Name == `paxandwayne.internal.`].[Id]' --output text)
zone=$(aws route53 list-hosted-zones-by-name --dns-name $r53zone. |grep Id |cut -d ":" -f2 |tr -d '", ')
zoneid=$(echo "$zone" | cut -d "/" -f 3)
jsonstr="{
    "\""Comment"\"": "\""Update record to reflect new IP address of home router"\"",
    "\""Changes"\"": [
        {
            "\""Action"\"": "\""UPSERT"\"",
            "\""ResourceRecordSet"\"": {
                "\""Name"\"": "\""$r53record.$r53zone."\"",
                "\""Type"\"": "\""A"\"",
                "\""TTL"\"": 300,
                "\""ResourceRecords"\"": [
                    {
                        "\""Value"\"": "\""$ipaddr"\""
                    }
                ]
            }
        }
    ]
}"
jsonstr="{ \"ChangeBatch\": $jsonstr }"

#Update Route53 record
aws route53 change-resource-record-sets --hosted-zone-id "$zoneid" --cli-input-json "$jsonstr"


#Get MAC addr and subnet ID
macaddr=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs | cut -d "/" -f 1)
subid=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$macaddr/subnet-id)
rtid=$(aws --region us-west-2 ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$subid" |grep -m1 RouteTableId |cut -d ":" -f2 |tr -d '"')

#Get INSTANCE_ID
export INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

#Update AWWS source dest checking to false
aws --region us-west-2 ec2 modify-instance-attribute --instance-id $INSTANCE_ID --source-dest-check "{\"Value\": false}"

#Update AWS Route Tables
# Update route tables
aws --region us-west-2 ec2 replace-route --route-table-id $rtid --destination-cidr-block $lansubnet --instance-id $INSTANCE_ID
aws --region us-west-2 ec2 replace-route --route-table-id $rtid --destination-cidr-block $lansubnet --instance-id $INSTANCE_ID
#aws --region us-west-2 ec2 replace-route --route-table-id rtb-ac1120cb --destination-cidr-block 192.168.1.0/24 --instance-id $INSTANCE_ID
#aws --region us-west-2 ec2 replace-route --route-table-id rtb-ac1120cb --destination-cidr-block 192.168.10.0/24 --instance-id $INSTANCE_ID
#aws --region us-west-2 ec2 replace-route --route-table-id rtb-ac1120cb --destination-cidr-block 0.0.0.0/0 --instance-id $INSTANCE_ID

echo "Updating AWS settings (ec2 source dest check + route tables)">>$logfile
# Set ec2 source dest checking to false
aws --region us-west-2 ec2 modify-instance-attribute --instance-id $INSTANCE_ID --source-dest-check "{\"Value\": false}"

#Download openvpn files
aws --region us-west-2 s3 --recursive cp $openvpnfiles /openvpn

# Install openvpn
echo "Installing openvpn" >>$logfile
sudo amazon-linux-extras install epel -y
#sudo yum clean dbcache
sudo yum install -y openvpn

#NAT GW Settings
echo "Setting ip_forward / NAT">>$logfile
sysctl -w net.ipv4.ip_forward=1
echo "Enabling NAT iptables">>$logfile
/usr/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

#Setup forwarding and iptables
echo "Setting iptables rules">>$logfile
/usr/sbin/sysctl -w net.ipv4.ip_forward=1
/usr/sbin/iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT 2>&1
/usr/sbin/iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>&1
/usr/sbin/iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE 2>&1


#Forwarding rules
#iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80:65535 -j DNAT --to $lanipaddr:80-65535
#iptables -A FORWARD -p tcp -d $lanipaddr --dport 80:65535 -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80:1193 -j DNAT --to $lanipaddr:80-1193
iptables -A FORWARD -p tcp -d $lanipaddr --dport 80:1193 -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 1195:65535 -j DNAT --to $lanipaddr:1195-65535
iptables -A FORWARD -p tcp -d $lanipaddr --dport 1195:65535 -j ACCEPT
#iptables -t nat -A PREROUTING -i eth0 -p udp --dport 80:65535 -j DNAT --to $lanipaddr:80-65535
#iptables -A FORWARD -p udp -d $lanipaddr --dport 80:65535 -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 80:1193 -j DNAT --to $lanipaddr:80-1193
iptables -A FORWARD -p udp -d $lanipaddr --dport 80:1193 -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 1195:65535 -j DNAT --to $lanipaddr:1195-65535
iptables -A FORWARD -p udp -d $lanipaddr --dport 1195:65535 -j ACCEPT

#Update Cloudflare
yum install -y ddclient
ddclient --file /openvpn/ddclient.conf -force


#Start openvpn
echo "Starting VPN">>$logfile
#openvpn --config pfSense-UDP4-1194-vpnuser.ovpn
cd /openvpn
mkdir -p /ccd
echo 
mkdir -p /var/log/openvpn
mv client /ccd/
openvpn --config server.conf

echo "Startup script finished" >>$logfile
exit




#NAT GW Settings
#sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sysctl -w net.ipv4.ip_forward=1
/usr/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

#Setup forwarding and iptables
#echo "Setting iptables rules">>$logfile
#/usr/sbin/sysctl -w net.ipv4.ip_forward=1
#/usr/sbin/iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT 2>&1
#/usr/sbin/iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>&1
#/usr/sbin/iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE 2>&1
##/sbin/iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT 2>&1
