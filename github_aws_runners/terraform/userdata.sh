#!/bin/bash
tee /etc/docker/daemon.json <<EOF
{
    "features": {
        "containerd-snapshotter": true
    }
}
EOF
service docker restart
mkdir -p /home/ec2-user/.aws
tee -a /home/ec2-user/.aws/config <<EOF
[profile ${default_profile_name}]
EOF