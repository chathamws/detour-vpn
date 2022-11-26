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
S3: Used to stage and store files for the build process
# Setup
 




