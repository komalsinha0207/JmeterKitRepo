#!/bin/bash
INSTANCE_ID="i-094ae85fdc8f36df2"  # Replace with the instance ID
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
INSTANCE_NAME="PL_LAB_MASTER_XL1_V1"

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value="aws:///$REGION/$INSTANCE_NAME"
