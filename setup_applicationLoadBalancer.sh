# Extracting VPC ID from the log file
vpc_id=$(awk '/VpcId/{print $2}' vpc.log)

# Creating a security group for ALB
aws ec2 create-security-group --group-name "alb-group" --description "allows http traffic on port 80 from anywhere" --vpc-id $vpc_id --output text >> /dev/null

echo "Security group is created."

# Retrieving the security group ID
group_id=$(aws ec2 describe-security-groups --query "SecurityGroups[?VpcId=='$vpc_id' && GroupName=='alb-group'].GroupId" --output text)

# Logging the security group ID
echo "alb_GroupId $group_id" >> vpc.log

# Authorizing ingress traffic to the security group
aws ec2 authorize-security-group-ingress --group-id $group_id --protocol tcp --port 80 --cidr 0.0.0.0/0 >> /dev/null

# Creating a target group for the ALB
aws elbv2 create-target-group --vpc-id $vpc_id --target-type instance --protocol HTTP --port 8000 --health-check-enabled --health-check-protocol HTTP --healthy-threshold-count 5 --unhealthy-threshold-count 5 --health-check-port traffic-port --health-check-path "/" --health-check-interval-seconds 30 --name DjangoAppTargetGroups >> /dev/null

echo "Target group is created."

# Retrieving the target group ARN
target_group_arn=$(aws elbv2 describe-target-groups --names DjangoAppTargetGroups --query "TargetGroups[0].TargetGroupArn" --output text)

# Logging the target group ARN
echo "TargetGroupArn $target_group_arn" >> vpc.log

# Extracting subnets from the log file
subnets=()
index=0
for subnet in $(awk '/SubnetId/{print $2}' vpc.log); do
    subnets[index]=$subnet
    index=$(($index + 1))
done

# Creating an Internet-facing load balancer
aws elbv2 create-load-balancer --name alb --scheme internet-facing --subnets "${subnets[@]}" --security-groups $group_id >> /dev/null

echo "Applicatin Load Balancer is created."

# Retrieving the load balancer ARN
load_balancer_arn=$(aws elbv2 describe-load-balancers --names alb --query "LoadBalancers[0].LoadBalancerArn" --output text)

# Logging the load balancer ARN
echo "LoadBalancerArn $load_balancer_arn" >> vpc.log

# Creating a listener for the load balancer
aws elbv2 create-listener --load-balancer-arn $load_balancer_arn --protocol HTTP --port 80 --default-action Type=forward,TargetGroupArn=$target_group_arn >> /dev/null

echo "Listener for appliation load balancer is created."
