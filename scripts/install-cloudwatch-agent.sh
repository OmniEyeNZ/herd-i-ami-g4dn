#!/bin/bash
set -e

echo "=========================================="
echo "Installing CloudWatch Agent"
echo "=========================================="

# Download CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb

# Install CloudWatch Agent
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb

# Clean up
rm /tmp/amazon-cloudwatch-agent.deb

# Verify installation
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -h || true

echo "=========================================="
echo "CloudWatch Agent installed successfully!"
echo "=========================================="
