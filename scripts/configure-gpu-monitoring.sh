#!/bin/bash
set -e

echo "=========================================="
echo "Configuring GPU Monitoring for CloudWatch"
echo "=========================================="

# Copy CloudWatch configuration with nvidia_gpu section
sudo cp /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json

# Verify NVIDIA drivers are available (required for CloudWatch agent GPU metrics)
echo "Verifying NVIDIA GPU availability..."
nvidia-smi

echo "=========================================="
echo "GPU Monitoring configured successfully!"
echo ""
echo "The CloudWatch agent will automatically collect GPU metrics using the"
echo "built-in nvidia_gpu support when started on instance launch."
echo ""
echo "18 GPU metrics will be collected including:"
echo "  - GPU utilization, memory utilization, temperature, power draw"
echo "  - Fan speed, memory (total/used/free)"
echo "  - PCIe link generation and width"
echo "  - Clock frequencies (graphics, SM, memory, video)"
echo "  - Encoder stats (session count, FPS, latency)"
echo ""
echo "Metrics will appear in CloudWatch namespace: CWAgent"
echo "With dimensions: Index, Name, Architecture"
echo "=========================================="
