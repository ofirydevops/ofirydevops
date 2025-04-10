#!/bin/bash
mkdir -p /home/ec2-user/.aws
tee -a /home/ec2-user/.aws/config <<EOF
[profile ${default_profile_name}]
EOF