# Herd-i AMI Base - G4dn GPU Monitoring AMI

## Project Overview

Automated AMI build pipeline using Packer to create GPU-optimized Amazon Machine Images for AWS G4dn instances. Provides a ready-to-use foundation for GPU workloads with comprehensive monitoring, Docker containerization support, and optional pre-loaded images to minimize deployment time.

## Deployment Summary

**Deploy:** Herd-i AMI Base - G4dn GPU Monitoring
**Repo:** https://github.com/OmniEyeNZ/herd-i-ami-base
**GitHub Action:** Build GPU AMI with Packer
**Description:** Packer configuration to build optimized AWS AMIs for G4dn GPU instances with automated CloudWatch monitoring for CPU, RAM, disk, and GPU metrics. Pre-installs Docker with NVIDIA Container Toolkit, CloudWatch agent, and optional Docker image pre-loading to reduce instance startup time. Built on AWS Deep Learning Base GPU AMI (Ubuntu 24.04) with NVIDIA drivers.
**Destination:** AWS AMI (EC2 Image)
**AWS Services:** EC2, AMI, CloudWatch (Metrics & Agent), EBS (gp3 volumes)

## Features

- **Base AMI**: AWS Deep Learning Base GPU AMI (Ubuntu 24.04) with pre-installed NVIDIA drivers
- **Docker**: Latest Docker Engine with NVIDIA Container Toolkit for GPU-accelerated containers
- **CloudWatch Monitoring**: Comprehensive monitoring for CPU, RAM, Disk, and GPU metrics
- **GPU Metrics**: Automated collection of GPU utilization, memory, temperature, and power usage
- **Pre-loaded Docker Images**: Optional pre-loading of Docker images to reduce instance startup time
- **ECR Support**: Automatic ECR authentication for environment-specific Docker image pre-loading
- **Multi-Environment**: Supports development, test, and production environments with separate AWS accounts
- **Optimized Storage**: 100GB gp3 volume with 3000 IOPS and 125 MB/s throughput

## Environment Architecture

This project is designed to work with multiple environments, each with its own AWS account:

- **Development**: Uses development AWS account and ECR repositories
- **Test**: Uses test AWS account and ECR repositories
- **Production**: Uses production AWS account and ECR repositories

The GitHub Actions workflow uses GitHub Environments to manage environment-specific secrets (AWS credentials). When you select an environment during the workflow run, it automatically uses the correct AWS account credentials for that environment.

### How ECR Image Pre-loading Works

1. You specify an ECR repository name (e.g., `task-lameness`) during the workflow run
2. The workflow gets the AWS Account ID from the selected environment's credentials
3. It constructs the full ECR URL: `{account-id}.dkr.ecr.{region}.amazonaws.com/{repository}:{tag}`
4. During AMI build, the Packer provisioner:
   - Detects the ECR URL format
   - Authenticates with ECR using the instance's AWS credentials
   - Pulls the specified Docker image
   - Logs out from ECR

This allows each environment to pre-load images from its own ECR repositories.

## GPU Metrics Collected

The AMI uses CloudWatch agent's built-in **nvidia_gpu** support to automatically collect **18 GPU metrics**:

**Core Performance Metrics:**
- GPU Utilization (Percent)
- GPU Memory Utilization (Percent)
- GPU Temperature (Celsius)
- GPU Power Draw (Watts)
- GPU Fan Speed (Percent)

**Memory Metrics:**
- Total Memory (MB)
- Used Memory (MB)
- Free Memory (MB)

**Hardware Metrics:**
- PCIe Link Generation (Current)
- PCIe Link Width (Current)

**Clock Frequencies:**
- Graphics Clock (MHz)
- SM (Streaming Multiprocessor) Clock (MHz)
- Memory Clock (MHz)
- Video Clock (MHz)

**Encoder Metrics:**
- Encoder Session Count
- Average FPS
- Average Latency

**Metric Details:**
- Collection Interval: 60 seconds
- Namespace: `CWAgent`
- Dimensions: `Index` (GPU ID), `Name` (GPU type), `Architecture` (server architecture)

This follows the [official AWS CloudWatch GPU monitoring documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-NVIDIA-GPU.html).

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── Deploy.yml           # GitHub Actions workflow for AMI builds
├── configs/
│   └── cloudwatch-config.json   # CloudWatch agent configuration
├── scripts/
│   ├── install-docker.sh        # Docker and NVIDIA Container Toolkit installation
│   ├── install-cloudwatch-agent.sh
│   ├── configure-gpu-monitoring.sh
│   └── preload-docker-image.sh
├── local-deployment/
│   ├── .env                     # Environment variables for local testing
│   └── .secrets.example         # Example secrets file
├── packer.pkr.hcl              # Main Packer template
├── variables.pkr.hcl           # Packer variables
└── README.md
```

## Prerequisites

1. **AWS Account** with permissions to:
   - Create EC2 instances
   - Create AMIs
   - Describe images
   - Create security groups and key pairs

2. **Packer** installed locally (for local builds)
   ```bash
   # Install Packer
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   unzip packer_1.10.0_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

3. **AWS Credentials** configured
   ```bash
   export AWS_ACCESS_KEY_ID=your-key-id
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   ```

## Building the AMI

### Using GitHub Actions (Recommended)

1. Navigate to the **Actions** tab in your GitHub repository
2. Select **Build GPU AMI with Packer** workflow
3. Click **Run workflow**
4. Configure the inputs:
   - **Packer Action**: Choose `validate` to test or `build` to create the AMI
   - **AWS Region**: Choose `Sydney` (ap-southeast-2) or `Oregon` (us-west-2)
   - **Environment**: Choose the environment (`development`, `test`, or `production`)
   - **ECR Repository** (optional): Specify an ECR repository name to pre-load an image (e.g., `task-lameness`)
   - **Docker Image Tag** (optional): Tag for the ECR image (default: `latest`)
   - **Public Docker Image** (optional): Specify a public Docker image (e.g., `nvidia/cuda:12.4.0-base-ubuntu24.04`)
5. Click **Run workflow**

**Note**: The workflow uses environment-specific AWS credentials from GitHub Environments. Each environment (development, test, production) uses a different AWS account.

The workflow will output the AMI ID upon completion.

### Environment-Specific Builds

This project supports building AMIs for different environments with environment-specific Docker images:

**Example 1: Pre-load from ECR (Environment-Specific)**
```
Environment: development
AWS Region: Sydney
ECR Repository: task-lameness
Docker Image Tag: latest
```
This will pull the image from your development AWS account's ECR repository.

**Example 2: Pre-load from Public Docker Hub**
```
Environment: production
AWS Region: Oregon
Public Docker Image: nvidia/cuda:12.4.0-base-ubuntu24.04
```
This will pull the public NVIDIA CUDA image.

### Using Packer Locally

1. **Set AWS Credentials**
   ```bash
   export AWS_ACCESS_KEY_ID=your-key-id
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   export AWS_REGION=ap-southeast-2
   ```

2. **Initialize Packer**
   ```bash
   packer init packer.pkr.hcl
   ```

3. **Validate the template**

   For public Docker images:
   ```bash
   packer validate \
     -var "aws_region=ap-southeast-2" \
     -var "docker_image=nvidia/cuda:12.4.0-base-ubuntu24.04" \
     packer.pkr.hcl
   ```

   For ECR images:
   ```bash
   # Get your AWS account ID
   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

   packer validate \
     -var "aws_region=ap-southeast-2" \
     -var "docker_image=${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-2.amazonaws.com/task-lameness:latest" \
     packer.pkr.hcl
   ```

4. **Build the AMI**

   For public Docker images:
   ```bash
   packer build \
     -var "aws_region=ap-southeast-2" \
     -var "docker_image=nvidia/cuda:12.4.0-base-ubuntu24.04" \
     packer.pkr.hcl
   ```

   For ECR images:
   ```bash
   # Get your AWS account ID
   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

   packer build \
     -var "aws_region=ap-southeast-2" \
     -var "docker_image=${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-2.amazonaws.com/task-lameness:latest" \
     packer.pkr.hcl
   ```

   **Note**: When using ECR images, the Packer build will automatically authenticate with ECR during the image pre-load phase.

### Local Testing with Act

For local testing of GitHub Actions workflows:

1. **Setup local-deployment configuration**
   ```bash
   cd local-deployment
   cp .secrets.example .secrets
   # Edit .secrets with your AWS credentials
   # Edit .env to set ECR_REPOSITORY or DOCKER_IMAGE_PUBLIC
   ```

2. **Run with act**

   For validation:
   ```bash
   act workflow_dispatch \
     --secret-file local-deployment/.secrets \
     --env-file local-deployment/.env \
     --input packer_action=validate \
     --input aws_region=Sydney \
     --input environment=development
   ```

   For building with ECR image:
   ```bash
   act workflow_dispatch \
     --secret-file local-deployment/.secrets \
     --env-file local-deployment/.env \
     --input packer_action=build \
     --input aws_region=Sydney \
     --input environment=development \
     --input ecr_repository=task-lameness \
     --input docker_image_tag=latest
   ```

## Using the AMI

Once the AMI is built, you can launch EC2 instances using it:

```bash
aws ec2 run-instances \
  --image-id ami-xxxxxxxxx \
  --instance-type g4dn.xlarge \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --iam-instance-profile Name=YourInstanceProfileWithCloudWatchPermissions
```

### Required IAM Permissions for Instances

Instances launched from this AMI need the following IAM permissions for GPU monitoring:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
```

### Starting CloudWatch Agent

The CloudWatch agent is pre-installed but not started by default. To start it on an instance:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json
```

The GPU metrics timer will start automatically on boot.

## Customization

### Variables

You can customize the AMI build by modifying `variables.pkr.hcl` or passing variables via command line:

- `aws_region`: AWS region to build in (default: us-east-1)
- `ami_name_prefix`: Prefix for AMI name (default: g4dn-gpu-monitored)
- `instance_type`: Build instance type (default: g4dn.xlarge)
- `docker_image`: Docker image to pre-load (default: empty)
- `volume_size`: Root volume size in GB (default: 100)

### CloudWatch Configuration

Modify `configs/cloudwatch-config.json` to adjust:
- Metrics collection interval
- Additional metrics to collect
- Namespace for metrics

### GPU Monitoring Configuration

GPU metrics are collected automatically by the CloudWatch agent using its built-in `nvidia_gpu` support. The configuration is located in `configs/cloudwatch-config.json`. You can customize which GPU metrics are collected by modifying the `nvidia_gpu` section before building the AMI.

## Viewing GPU Metrics in CloudWatch

1. Open the CloudWatch console
2. Navigate to **Metrics** → **All metrics**
3. Select the **CWAgent** namespace
4. Choose metrics by dimensions:
   - **Index**: GPU identifier (0, 1, 2, etc.)
   - **Name**: GPU type (e.g., "NVIDIA Tesla T4")
   - **Architecture**: Server architecture (e.g., "x86_64")
5. Look for metrics starting with `GPU_` prefix (e.g., `GPU_UTILIZATION`, `GPU_TEMPERATURE`)
6. Create dashboards and alarms as needed

## Troubleshooting

### GPU Metrics Not Appearing in CloudWatch

1. Verify the instance has an IAM role with CloudWatch permissions
2. Check the CloudWatch agent is running:
   ```bash
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
     -a query -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json
   ```

3. Verify NVIDIA drivers are working:
   ```bash
   nvidia-smi
   ```

4. Check CloudWatch agent logs:
   ```bash
   sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
   ```

5. Ensure the configuration includes the `nvidia_gpu` section:
   ```bash
   sudo cat /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json | grep -A 5 nvidia_gpu
   ```

### Docker Not Working with GPU

1. Verify NVIDIA drivers:
   ```bash
   nvidia-smi
   ```

2. Test GPU access with Docker:
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi
   ```

### ECR Image Pre-loading Issues

**Error: "Failed to authenticate with ECR"**
- Ensure the Packer build instance has an IAM role with ECR permissions:
  ```json
  {
    "Effect": "Allow",
    "Action": [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ],
    "Resource": "*"
  }
  ```
- The Packer template automatically creates this role, but verify it exists

**Error: "Failed to pull Docker image"**
- Verify the ECR repository exists in the target environment's AWS account
- Confirm the specified image tag exists in the repository
- Check that the image is compatible with the AMI architecture (linux/amd64)

**Wrong Environment's Image**
- Ensure you selected the correct environment in the GitHub Actions workflow
- Each environment (development/test/production) has separate AWS accounts and ECR repositories
- The AMI name includes the environment to help identify which account it was built in

## Cost Considerations

- **Build Cost**: Building the AMI requires running a G4dn instance for ~15-20 minutes
- **Storage Cost**: AMI snapshots incur EBS storage costs
- **Instance Cost**: G4dn instances have higher costs than standard instances

## Version History

AMI versions are tracked using git tags in the format `v1.2.3`. Each build includes the version in the AMI name.

## License

Copyright © 2025 Herd-i. All rights reserved.

## Support

For issues or questions, please contact the Herd-i DevOps team.
