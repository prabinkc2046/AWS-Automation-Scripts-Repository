# This script creates a Virtual Private Cloud (VPC) in the ap-southeast-2 region with a specified CIDR block and name tag.
# It then creates two subnets in different availability zones within the VPC.
# The script associates a route table with each subnet and creates an Internet Gateway, attaching it to the VPC.
# Finally, a route to the Internet Gateway is added to enable internet connectivity.

# Create a VPC with a specific CIDR block and name tag in the ap-southeast-2 region
aws ec2 create-vpc --region ap-southeast-2 --cidr-block 10.0.0.0/16 --tag-specifications "ResourceType=vpc,Tags=[{Key=name,Value=myvpc}]" >> /dev/null
echo "VPC is created."

# Assign the VPC ID to a variable for later use
vpc_id=$(aws ec2 describe-vpcs --region ap-southeast-2 --query "Vpcs[?Tags[?Key=='name' && Value=='myvpc']].VpcId" --output text) >> /dev/null
echo "VpcId $vpc_id" >> vpc.log

# Create two subnets within the VPC in different availability zones
aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.1.0/24 --availability-zone ap-southeast-2a  >> /dev/null
aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.2.0/24 --availability-zone ap-southeast-2b  >> /dev/null
echo "Subnets are created."

# Retrieve the route table ID associated with the VPC
route_table_id=$(aws ec2 describe-route-tables --query "RouteTables[?VpcId=='$vpc_id'].RouteTableId" --output text) >> /dev/null

# Associate each subnet with the retrieved route table
subnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='$vpc_id'].SubnetId" --output text)
for subnet_id in $subnets; do 
  aws ec2 associate-route-table --route-table-id $route_table_id --subnet-id $subnet_id >> /dev/null
	echo "SubnetId $subnet_id" >> vpc.log
done
echo "Subnets are associated with the route table."

# Create an Internet Gateway and attach it to the VPC
aws ec2 create-internet-gateway >> /dev/null
internet_gateway_id=$(aws ec2 describe-internet-gateways --query "InternetGateways[0].InternetGatewayId" --output text) >> /dev/null
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $internet_gateway_id >> /dev/null
echo "Internet Gateway is created and attached to the VPC."

# Configure a route to the Internet Gateway to enable internet connectivity
aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $internet_gateway_id >> /dev/null
echo "Route to the internet is configured."
