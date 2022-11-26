#!/bin/bash

usage() { echo \
'Usage: $0 [-n --name <string>] [-s --s3bucket <string>] [-v --vpc] [-i --ipnets] [-d --dns]
-n --name      <string>   Required  Name to assign the cloudformation stack
-s --s3bucket  <string>   Required  Specify s3 bucket to use, must contain an openvpn folder with
                                    required openvpn and ddupdate config
                                    ex. s3://somebucket
-v --vpc       <string>   Optional  Specify an existing VPC ID, default is to create new VPC
                                    ex. vpc-a1d944c6
-i --ipnets     <list>    Optional  Required if -v --vpc specified. List of AWS subnets to use
                                    ex. \"subnet-056e44bf50a7f5f211,subnet-00fe0d47c3d6153ebb,subnet-02bbedc830b5d0db99\"
-d --dns       <string>   Optional  Route53 zone to use, default is dns.internal
'
1>&2; exit 1; }

#Defaults
build_vpc=yes
r53_zone="dns.internal"
ipnets=\"\"

VALID_ARGS=$(getopt -o ?n:s:v:i: --long name:,s3bucket:,vpc:,ipnets: -- "$@")
if [[ $? -ne 0 ]]; then
    usage
	exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -n | --name)
		stackname=$2
        shift 2
        ;;
    -s | --s3bucket)
		s3_bucket=$2
        shift 2
        ;;
	-v | --vpc)
		build_vpc=no
		vpc_id=$2
        shift 2
        ;;
	-i | --ipnets)
		ipnets=$2
        shift 2
        ;;
	-d | --dns)
		r53_zone=$2
        shift 2
        ;;
    --) shift; 
        break 
        ;;
  esac
done

if [ -z $stackname ] ; then
  echo -e "ERROR: Missing option -n --name for stack name\n"
  usage
fi
if [ -z $s3_bucket ] ; then
  echo -e "ERROR: Missing option -s --s3bucket for s3 bucket\n"
  usage
fi
if [ "$build_vpc" = no ] && [ -z $ipnets ]; then
  echo -e "ERROR: Option to use VPC is set, however no subnets were specified\n"
  usage
fi

s3_cfpath=$s3_bucket/cloudformation/$stackname

echo -e "Proceeding with these options set:
Stack Name: $stackname
S3 Bucket: $s3_bucket
S3 CF Path: $s3_cfpath
Create VPC: $build_vpc
Route53: $r53_zone"

if [ "$build_vpc" = no ] ; then
  echo "VPC ID: $vpc_id"
  echo "Subnets: $ipnets"
fi


echo "
Staging $stackname files to $s3_cfpath" 
copyFiles=("natgw_userdata.sh" "startupscript.sh")
#scripts/natgw_userdata.sh script to execute on first boot, init of startupscript
#scripts/startupscript.sh script to execute every boot

for f in ${copyFiles[@]}; do
  f="scripts/$f"
  aws s3 cp ./$f $s3_cfpath/
done

echo "
Staging openvpn files to $s3_cfpath/openvpn"
checkFiles=("ipp.txt" "client" "ddclient.conf" "pfSense-CA.crt" "pfSense-server.crt" "pfSense-server.key" "server.conf" "tls.key")
for f in ${checkFiles[@]}; do
  f="openvpn/$f"
  if [ ! -f $f ]; then
    echo "ERROR: $f not found!"
	exit
  else
    aws s3 cp ./$f $s3_cfpath/openvpn/
  fi
done

echo " "

#Create params file from tempalte
file_input=./templates/params.template.json
file_output=params.json
eval "echo \"$(< $file_input)\"" > $file_output

if [ "$build_vpc" = yes ] ; then
  template="vpc.template"
  depstack=vpc-$stackname
  echo "Deploying $depstack from template: vpc.template"
  aws --region us-west-2 cloudformation create-stack \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
	  --stack-name $depstack \
	  --template-body file://templates/vpc.template \
	  --parameters \
	  ParameterKey=PrivateDnsZoneName,ParameterValue=$r53_zone
  echo "Waiting for VPC stack creation to complete"
  aws cloudformation wait stack-create-complete --stack-name $depstack
fi

echo "Deploying $stackname from template: natgw.template"
aws --region us-west-2 cloudformation create-stack \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
	--stack-name $stackname \
	--template-body file://templates/natgw.template \
	--parameters file://params.json

exit