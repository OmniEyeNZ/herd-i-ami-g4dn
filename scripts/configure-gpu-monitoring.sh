#!/bin/bash
set -e

echo "=========================================="
echo "Configuring GPU Monitoring for CloudWatch"
echo "=========================================="

# Install nvidia-smi monitoring script
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/bin/scripts

# Create GPU metrics collection script
sudo tee /opt/aws/amazon-cloudwatch-agent/bin/scripts/gpu-metrics.sh > /dev/null <<'EOF'
#!/bin/bash
# GPU Metrics Collection Script for CloudWatch
# This script collects NVIDIA GPU metrics using nvidia-smi

INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')

# Get GPU metrics from nvidia-smi
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits | head -1)

for GPU_INDEX in $(seq 0 $(($GPU_COUNT - 1))); do
    # Query all metrics at once for efficiency
    METRICS=$(nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits --id=$GPU_INDEX)

    GPU_UTIL=$(echo $METRICS | awk '{print $1}')
    MEM_UTIL=$(echo $METRICS | awk '{print $2}')
    MEM_USED=$(echo $METRICS | awk '{print $3}')
    MEM_TOTAL=$(echo $METRICS | awk '{print $4}')
    GPU_TEMP=$(echo $METRICS | awk '{print $5}')
    POWER_DRAW=$(echo $METRICS | awk '{print $6}')

    # Calculate memory percentage
    MEM_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($MEM_USED/$MEM_TOTAL)*100}")

    # Send metrics to CloudWatch
    aws cloudwatch put-metric-data \
        --namespace "GPU/Metrics" \
        --metric-name "GPUUtilization" \
        --value $GPU_UTIL \
        --unit Percent \
        --dimensions InstanceId=$INSTANCE_ID,GPUIndex=$GPU_INDEX \
        --region $REGION

    aws cloudwatch put-metric-data \
        --namespace "GPU/Metrics" \
        --metric-name "GPUMemoryUtilization" \
        --value $MEM_PERCENT \
        --unit Percent \
        --dimensions InstanceId=$INSTANCE_ID,GPUIndex=$GPU_INDEX \
        --region $REGION

    aws cloudwatch put-metric-data \
        --namespace "GPU/Metrics" \
        --metric-name "GPUMemoryUsed" \
        --value $MEM_USED \
        --unit Megabytes \
        --dimensions InstanceId=$INSTANCE_ID,GPUIndex=$GPU_INDEX \
        --region $REGION

    aws cloudwatch put-metric-data \
        --namespace "GPU/Metrics" \
        --metric-name "GPUTemperature" \
        --value $GPU_TEMP \
        --unit None \
        --dimensions InstanceId=$INSTANCE_ID,GPUIndex=$GPU_INDEX \
        --region $REGION

    aws cloudwatch put-metric-data \
        --namespace "GPU/Metrics" \
        --metric-name "GPUPowerDraw" \
        --value $POWER_DRAW \
        --unit None \
        --dimensions InstanceId=$INSTANCE_ID,GPUIndex=$GPU_INDEX \
        --region $REGION
done
EOF

sudo chmod +x /opt/aws/amazon-cloudwatch-agent/bin/scripts/gpu-metrics.sh

# Create systemd service for GPU monitoring
sudo tee /etc/systemd/system/gpu-cloudwatch-metrics.service > /dev/null <<'EOF'
[Unit]
Description=GPU CloudWatch Metrics Collection
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/aws/amazon-cloudwatch-agent/bin/scripts/gpu-metrics.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer for GPU monitoring (runs every minute)
sudo tee /etc/systemd/system/gpu-cloudwatch-metrics.timer > /dev/null <<'EOF'
[Unit]
Description=GPU CloudWatch Metrics Collection Timer
Requires=gpu-cloudwatch-metrics.service

[Timer]
Unit=gpu-cloudwatch-metrics.service
OnBootSec=2min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF

# Enable the timer (don't start it now as we're in the build phase)
sudo systemctl daemon-reload
sudo systemctl enable gpu-cloudwatch-metrics.timer

# Copy CloudWatch configuration
sudo cp /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json

echo "=========================================="
echo "GPU Monitoring configured successfully!"
echo "The GPU metrics timer will start automatically on first boot"
echo "=========================================="
