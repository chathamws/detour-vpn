# detour-vpn
AWS NAT Gateway VPN Instance\
Used to bypass CGNAT (Carrier Grade NAT) and provides a public IP to tunnel traffic to your home network.\
This was built and tested with pfSense equipment, though this can be used with anything supporting openvpn support.\




## Overview
This was built and tested with pfSense on a T-Mobile 5G home internet connection. An EC2 instance is configured as an openvpn server with a public IP address. ddclient is used to update public DNS providers such as Cloudflare with the instance public IP upon startup.\
pfSense is used as the openvpn client as well as the certificate authority for the connection.\
\
Once setup is complete, the EC2 instance will route tcp/udp ports 80-1193, 1196-65535 to your LAN IP. pfSense can be used to NAT traffic to your local network or in a more advanced configuration HA Proxy can be configured as your destination for hosting multiple services on the same port.
```
                     +---------------+
                     |      AWS      |
                     |   +-------+   |
                     |   |       |   |
Home <---------------+---+  EC2  |<--+----------------- Internet
pfSense              |   |       |   |
                     |   +-------+   |
                     |               |
                     +---------------+
```

## AWS Components
VPC: default is to build a new one, however an existing one can be used\
EC2: Backed by an AWS ASG (Auto Scaling Group) to protect against AWS AZ outages.
S3: Used to stage and store files for the build process.
## Setup
Several file edits are required prior to executing the deployment script.
### Create/Edit files
Clone the example files (removing the .example extension) for each of the files below:\
#### ./templates/params.template.json - Config for EC2 and NAT
Modify values for the parameters listed below. Note, please leave the quotes and slashes in place:\
*R53Record:* This is optional and can leave as-is. DNS A recod to add to the AWS private DNS zone (zone name specified as a parameter in the deployment process)\
*LanSubnet:* This is your local LAN subnet that the instance will route traffic to over the VPN\
*LanIpAddr:* This is the destination IP on your local network to send all traffic. This will likely be .1 however you can use a different IP for another host such as HA Proxy\
#### ./openvpn/server.conf - Config file for OpenVPN server to use
If you are deploying to an existing VPC, you will need to edit the push "dhcp-option" DNS line with your AWS subnet Route53 resolver. If you will be deploying this configuration with defaults, you can leave this.\
Please ensure proper values for these lines (files must exist for each, see pfSense setup for instructions on how to create them):
ca pfSense-CA.crt\
cert pfSense-server.crt\
key pfSense-server.key\
tls-auth tls.key
#### ./openvpn/client - VPN Route for EC2
Update iroute statement with your local LAN subnet
#### ./openvpn/ddclient.conf
The example file is based on Cloudflare. Update login, password, and supply a comma separated list of all zone records to update withe the AWS public IP address.
## pfSense Setup
Coming soon







