#!/bin/bash

# This Bash script automates the creation of an Amazon Virtual Private Cloud (VPC) and associated resources.
# It specifies the CIDR block and region for the VPC, tags the VPC for identification, and logs information to 'vpc.log'.
# The script checks if a VPC with the specified tag already exists; if not, it creates the VPC.
# It then retrieves the VPC ID, lists available Availability Zones, and creates a subnet in each zone with CIDR blocks.
# Subnets are tagged based on their third octet, providing a structured and labeled VPC environment.
# Note: This script is designed for educational purposes and may need adjustments for production use.

# Specify the  cidr block and region for your vpc 
vpc_cidr_block=10.0.0.0/16
region=ap-southeast-2

# Specify the tags for your vpc
# Default key is "name" and value is "myvpc".
key=name
value=myvpc

# Create a file in the same directory where information about VPC will be logged
touch vpc.log

# This function creates a  VPC in the specified region and cidr- block
# This function also tags the vpc with specified key and value
create_vpc() {
    aws ec2 create-vpc \
    --cidr-block $vpc_cidr_block \
    --region $region \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=$key,Value=$value}]" >> /dev/null

    # Print information about the newly created VPC
    echo "New VPC with CIDR block $vpc_cidr_block in region: $region is created."
}

# Check if the VPC with specified  tag already exists
# If it exists, do not create VPC and exit
existing_vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:$key,Values=$value" --query "Vpcs[0].VpcId" --output text)

if [ "$existing_vpc_id" != "None" ]; then
    echo "VPC already exists with CIDR block  $vpc_cidr_block. Exiting..."
    exit
else
    echo "VPC with CIDR block $vpc_cidr_block does not exist in $region. Creating now..."
    #Calling function to create vpc
	create_vpc
fi

# Get the VPC ID of VPC created before
vpc_id=$(aws ec2 describe-vpcs \
--query "Vpcs[*].VpcId" \
--filters "Name=tag:name,Values=myvpc" --output text)
echo "VPC ID: $vpc_id" >> ./vpc.log

# List the available Availability Zones in the region
available_zones=$(aws ec2 describe-availability-zones \
--region ap-southeast-2 \
--query "AvailabilityZones[?State=='available'].ZoneName" \
--output text
)

# Create 1 subnet in each available zone
# Use subnet size of CIDR /24 incrementing the third octet by 1 
# First subnet will have subnet CIDR size of 1.0.1.0
# Second subnet will have subnet CIDR size of 1.0.2.0
# Similarly, incrementing the third octet by 1
# It also tags each subnet by its third octet value, e.g., subnet1 for 1.0.1.0
# and subnet2 for 1.0.2.0, etc.

subnetnumber=1
third_octet=1
create_subnet() {
    for zone in $available_zones; do
        subnet_cidr_block=10.0.$third_octet.0/24
        aws ec2 create-subnet --vpc-id $vpc_id --availability-zone $zone --cidr-block $subnet_cidr_block --tag-specifications "ResourceType=subnet,Tags=[{Key=name,Value=Subnet$subnetnumber}]" >> /dev/null
        echo "Subnet$subnetnumber is created in zone: $zone"
        subnetnumber=$((subnetnumber + 1))
        third_octet=$((third_octet + 1))
    done
}

# Calling the function to create 1 subnet in each available zone
create_subnet
