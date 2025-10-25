# Herd-i AMI G4dn - GPU Monitoring

## Project Overview

Automated AMI build pipeline using Packer to create GPU-optimized Amazon Machine Images for AWS G4dn instances. Provides a ready-to-use foundation for GPU workloads with comprehensive monitoring, Docker containerization support, and optional pre-loaded images to minimize deployment time.

## Deployment Summary

**Deploy:** Herd-i AMI G4dn - GPU Monitoring
**Repo:** https://github.com/OmniEyeNZ/herd-i-ami-g4dn
**GitHub Action:** Build GPU AMI with Packer
**Description:** Packer configuration to build optimized AWS AMIs for G4dn GPU instances with automated CloudWatch monitoring for CPU, RAM, disk, and GPU metrics. Pre-installs Docker with NVIDIA Container Toolkit, CloudWatch agent, and optional Docker image pre-loading to reduce instance startup time. Built on AWS Deep Learning Base GPU AMI (Ubuntu 24.04) with NVIDIA drivers.
**Destination:** AWS AMI (EC2 Image)
**AWS Services:** EC2, AMI, CloudWatch (Metrics & Agent), EBS (gp3 volumes)

---

# Local GitHub Actions Testing - Packer AMI Build

This directory contains scripts to test the Packer AMI build GitHub Actions workflow locally using [act](https://github.com/nektos/act).

## Quick Start

**First time setup:**
```bash
./local-deployment/boot.sh    # Install act, create config files, optionally sync from AWS
```

**Test Packer validation:**
```bash
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=validate \
  --input environment=development \
  --input aws_region=Sydney \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets
```

**Build AMI with act:**
```bash
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=development \
  --input aws_region=Sydney \
  --input ecr_repository=task-lameness \
  --input docker_image_tag=latest \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets
```

## Available Scripts

### 🚀 `boot.sh`
Bootstrap script that sets up the local testing environment.

**Usage:**
```bash
./boot.sh
```

**What it does:**
- Downloads and installs act locally to `./local-deployment/bin/`
- Creates `.env` and `.secrets` files from examples
- Verifies Docker and act installation
- Sets up the testing environment
- **Optionally syncs configuration from AWS:**
  - Downloads all secrets from AWS Secrets Manager → `.secrets` file
  - Downloads all SSM parameters starting with `GH_` → `.env` file

### 🔨 Testing Deploy.yml Workflow
The Packer AMI build workflow creates GPU-optimized AMIs for G4dn instances with CloudWatch monitoring.

**Manual Testing Examples (run from repository root):**

```bash
# Validate Packer Template for Development Environment
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=validate \
  --input environment=development \
  --input aws_region=Sydney \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets

# Build AMI with ECR Image Pre-loading (Development)
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=development \
  --input aws_region=Sydney \
  --input ecr_repository=task-lameness \
  --input docker_image_tag=latest \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets

# Build AMI with Public Docker Image
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=development \
  --input aws_region=Sydney \
  --input docker_image_public=nvidia/cuda:12.4.0-base-ubuntu24.04 \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets

# Build AMI without Pre-loading Any Docker Image
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=development \
  --input aws_region=Sydney \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets

# Validate Packer Template for Test Environment
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=validate \
  --input environment=test \
  --input aws_region=Sydney \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets

# Build AMI for Production Environment (Oregon Region)
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=production \
  --input aws_region=Oregon \
  --input ecr_repository=task-lameness \
  --input docker_image_tag=v1.2.3 \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets
```

**What it tests:**
- Packer template validation
- AWS Deep Learning Base GPU AMI selection (Ubuntu 24.04)
- Docker and NVIDIA Container Toolkit installation
- CloudWatch agent installation and configuration with nvidia_gpu support
- ECR authentication and Docker image pre-loading
- Public Docker image pre-loading
- Multi-environment support (development, test, production)
- Multi-region deployment (Sydney/Oregon)
- AWS credentials and region configuration
- Region mapping from user-friendly names (Sydney/Oregon) to AWS codes (ap-southeast-2/us-west-2)
- Environment-specific AMI naming
- Git-based semantic versioning for AMI names

## AMI Build Details

This workflow builds GPU-optimized AMIs for AWS G4dn instances:

### Base AMI
- **Source:** AWS Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 24.04)
- **Pre-installed:** NVIDIA drivers, CUDA toolkit
- **Supported Instances:** G4dn, G5, G6, Gr6, G6e, P4d, P4de, P5, P5e, P5en, P6-B200

### Components Installed
- **Docker Engine:** Latest stable version with NVIDIA Container Toolkit
- **CloudWatch Agent:** For CPU, RAM, disk monitoring
- **GPU Monitoring:** Custom systemd service for GPU metrics (utilization, memory, temperature, power)
- **Optional:** Pre-loaded Docker images (ECR or public)

### AMI Configuration
- **Instance Type for Build:** `g4dn.xlarge` (default)
- **Root Volume:** 100GB gp3, 3000 IOPS, 125 MB/s throughput
- **Build Time:** ~15-20 minutes

### AMI Naming Convention
- **Format:** `g4dn-gpu-monitored-{environment}-v{version}-{timestamp}`
- **Examples:**
  - Development: `g4dn-gpu-monitored-development-v1.0.0-20250125221530`
  - Test: `g4dn-gpu-monitored-test-v1.2.3-20250125221530`
  - Production: `g4dn-gpu-monitored-production-v2.0.0-20250125221530`

### Docker Image Pre-loading
The workflow supports two types of Docker image pre-loading:

**Option 1: ECR Repository (Environment-Specific)**
```bash
--input ecr_repository=task-lameness \
--input docker_image_tag=latest
```
This pulls the image from the environment's AWS account ECR:
- Development: `{dev-account-id}.dkr.ecr.ap-southeast-2.amazonaws.com/task-lameness:latest`
- Test: `{test-account-id}.dkr.ecr.ap-southeast-2.amazonaws.com/task-lameness:latest`
- Production: `{prod-account-id}.dkr.ecr.ap-southeast-2.amazonaws.com/task-lameness:latest`

**Option 2: Public Docker Image**
```bash
--input docker_image_public=nvidia/cuda:12.4.0-base-ubuntu24.04
```
This pulls a public image from Docker Hub or other public registries.

**Option 3: No Pre-loading**
Simply omit both `ecr_repository` and `docker_image_public` inputs to skip Docker image pre-loading.

### GPU Metrics Collected
The built AMI automatically collects **18 GPU metrics** using CloudWatch agent's built-in `nvidia_gpu` support:

**Core Performance:** GPU utilization, memory utilization, temperature, power draw, fan speed
**Memory:** Total, used, and free memory (MB)
**Hardware:** PCIe link generation/width
**Clock Frequencies:** Graphics, SM, memory, video clocks
**Encoder:** Session count, average FPS, latency

**Metric Details:**
- Collection Interval: 60 seconds
- Namespace: `CWAgent` (not GPU/Metrics)
- Dimensions: Index (GPU ID), Name (GPU type), Architecture
- Reference: [AWS CloudWatch GPU Monitoring](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-NVIDIA-GPU.html)

## Configuration

### Environment Variables (`.env`)

The `.env` file contains environment variables for the workflow. You can either:
1. **Create manually** from the template in the main README
2. **Sync from AWS SSM Parameter Store** using `./boot.sh` (downloads all parameters starting with `GH_`)
   - The `GH_` prefix is automatically stripped when downloading (e.g., `GH_AWS_REGION` becomes `AWS_REGION`)

Key variables you may need to customize:

```bash
# AWS Configuration
AWS_REGION=Sydney  # User-friendly name (Sydney/Oregon) that gets mapped to AWS region code
AWS_REGION_CODE=ap-southeast-2  # AWS region code
ENVIRONMENT_NAME=development

# Terraform State Configuration (if needed)
TERRAFORM_STATE_REGION_CODE=ap-southeast-2
TERRAFORM_STATE_BUCKET_PREFIX=herd-i-terraform-state
TERRAFORM_STATE_LOCKING_TABLE=herd-i-terraform-state-locking

# Packer Configuration
PACKER_AMI_NAME_PREFIX=g4dn-gpu-monitored
PACKER_INSTANCE_TYPE=g4dn.xlarge
PACKER_VOLUME_SIZE=100

# Docker Image Configuration
# Option 1: ECR Repository (for environment-specific images)
ECR_REPOSITORY=task-lameness
DOCKER_IMAGE_TAG=latest

# Option 2: Public Docker Image
DOCKER_IMAGE_PUBLIC=nvidia/cuda:12.4.0-base-ubuntu24.04

# Act Configuration
ACT_PLATFORM=ubuntu-latest=catthehacker/ubuntu:act-latest
```

### Secrets (`.secrets`)

The `.secrets` file contains sensitive credentials. You can either:
1. **Create manually** from `.secrets.example`
2. **Sync from AWS Secrets Manager** using `./boot.sh` (downloads all secrets automatically)

Required secrets:

```bash
# AWS Credentials (required for Packer AMI build operations)
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=your-secret-access-key

# DevOps Repository Token (optional, for triggering deployments)
DEVOPS_REPO_TOKEN=ghp_your-token

# Additional GitHub token (optional)
GITHUB_TOKEN=ghp_your-token
```

**Important:** Ensure AWS credentials have the following permissions:
- EC2: Create instances, create AMIs, create/delete snapshots
- VPC: Create security groups, describe subnets
- IAM: Pass role (for Packer builder instance)
- ECR: Get authorization token, pull images (if using ECR pre-loading)

## Multi-Environment Architecture

This project supports building AMIs for different environments with environment-specific configurations:

### Environment Separation
- **Development**: Uses development AWS account, ECR repositories, and credentials
- **Test**: Uses test AWS account, ECR repositories, and credentials
- **Production**: Uses production AWS account, ECR repositories, and credentials

### How It Works
1. Select an environment when running the workflow (development/test/production)
2. The workflow uses environment-specific AWS credentials from GitHub Environments
3. Packer builds the AMI in the selected environment's AWS account
4. If using ECR pre-loading, it pulls images from that environment's ECR repositories
5. AMI name includes the environment for easy identification

### Example Workflow Flow
```
Input: environment=development, ecr_repository=task-lameness, docker_image_tag=latest

↓

Uses development AWS credentials from GitHub Environment

↓

Gets AWS Account ID: 123456789012 (dev account)

↓

Constructs ECR URL: 123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/task-lameness:latest

↓

Packer builds AMI:
- Launches g4dn.xlarge in dev account
- Installs Docker, NVIDIA Container Toolkit
- Installs CloudWatch agent
- Configures GPU monitoring
- Authenticates with dev account ECR
- Pulls task-lameness:latest from dev ECR
- Creates AMI: g4dn-gpu-monitored-development-v1.0.0-20250125221530

↓

AMI is available in development AWS account
```

## Safety Considerations

⚠️ **Important**: These scripts are designed for local testing. They may:

- Launch EC2 instances (g4dn.xlarge) which incur costs (~$0.52/hour on-demand)
- Create AMIs in your AWS account
- Create EBS snapshots from the AMI (storage costs)
- Pull large Docker images (several GB of data transfer)
- Run for 15-20 minutes per build
- Consume significant local resources when running act

### Cost Estimates (per AMI build)
- **EC2 Instance:** ~$0.15-0.20 (15-20 minutes of g4dn.xlarge)
- **Data Transfer:** Varies (depends on Docker image size)
- **EBS Snapshot:** ~$0.05/GB per month (100GB AMI = ~$5/month)
- **AMI Storage:** EBS snapshot storage costs apply

### Recommended Testing Approach

1. **Start with dry runs**:
   ```bash
   ./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml --dry-run
   ```

2. **Test validation first**:
   ```bash
   # Safe - only validates Packer template, doesn't build
   ./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
     --input packer_action=validate \
     --input environment=development \
     --input aws_region=Sydney
   ```

3. **Use non-production AWS accounts**:
   - Configure `.secrets` with development/testing AWS credentials
   - Use development environment for testing
   - Avoid building in production until thoroughly tested

4. **Test different environments**:
   ```bash
   # Test development environment
   --input environment=development

   # Test test environment
   --input environment=test

   # Test production environment (use with caution)
   --input environment=production
   ```

5. **Skip Docker pre-loading for faster testing**:
   - Omit both `ecr_repository` and `docker_image_public` to skip image pre-loading
   - Reduces build time by ~2-5 minutes

6. **Clean up AMIs after testing**:
   - Delete test AMIs to avoid ongoing storage costs
   - Deregister AMI and delete associated snapshots

## Common Commands

```bash
# List available workflows (run from repository root)
./local-deployment/bin/act --list

# Run Deploy.yml with verbose output
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=validate \
  --input environment=development \
  --verbose

# Dry run to see what would execute
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=development \
  --dry-run

# Test different regions
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=validate \
  --input environment=development \
  --input aws_region=Oregon

# Use environment and secrets files
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --env-file ./local-deployment/.env --secret-file ./local-deployment/.secrets

# Build with specific Docker image tag
./local-deployment/bin/act workflow_dispatch -W ./.github/workflows/Deploy.yml \
  --input packer_action=build \
  --input environment=development \
  --input ecr_repository=task-lameness \
  --input docker_image_tag=v1.2.3
```

## Troubleshooting

### `act` not found
```bash
# Run bootstrap script to install act locally
./boot.sh
```

### Docker permission errors
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Missing secrets/environment
- Run `./boot.sh` to create configuration files or sync from AWS
- When syncing from AWS:
  - Requires valid AWS credentials in `.secrets` file first
  - Downloads all secrets from AWS Secrets Manager
  - Downloads all SSM parameters starting with `GH_`
- Edit `.env` and `.secrets` manually if not syncing from AWS
- Check that AWS credentials are valid for your target environment
- Ensure AWS credentials have EC2, AMI, and VPC permissions

### Packer-specific issues
- **AMI not found**: Ensure the region is correct and Deep Learning Base GPU AMI is available
- **Permission denied**: AWS credentials need EC2, AMI, VPC, and IAM permissions
- **Build timeout**: G4dn instance launch may take longer in some regions
- **SSH timeout**: Security group or network issues may prevent Packer from connecting

### ECR Image Pre-loading Issues
- **ECR authentication failed**: Ensure Packer instance has ECR permissions
- **Image not found**: Verify ECR repository and tag exist in the target environment
- **Wrong environment's image**: Confirm you selected the correct environment input
- **Pull timeout**: Large images may take several minutes to pull

### Workflow input validation
- **packer_action**: Must be one of: `validate`, `build`
- **aws_region**: Must be one of: `Sydney`, `Oregon` (user-friendly names that map to AWS region codes)
- **environment**: Must be one of: `development`, `test`, `production`
- **ecr_repository**: Optional, ECR repository name (e.g., `task-lameness`)
- **docker_image_tag**: Optional, defaults to `latest`
- **docker_image_public**: Optional, full public image name (e.g., `nvidia/cuda:12.4.0-base-ubuntu24.04`)

## Notes

- Local testing may behave differently than GitHub's hosted runners
- Some GitHub-specific contexts (`GITHUB_TOKEN`, runner environment) won't be available locally
- Network-dependent operations (Packer, AMI creation, ECR) require internet connectivity and proper credentials
- AMI builds will use real AWS resources and incur costs
- Each environment should use separate AWS accounts for proper isolation
- AMIs include environment name in the AMI name for easy identification
- GPU metrics are collected by CloudWatch agent's built-in nvidia_gpu support (18 metrics)
- CloudWatch agent is pre-installed but needs to be started on instance launch
- Docker images pre-loaded in the AMI save 2-5 minutes on instance startup time

## Using the Built AMI

After building an AMI with this workflow, you can launch instances:

```bash
# Get the AMI ID from the workflow output or AWS Console

# Launch an instance
aws ec2 run-instances \
  --image-id ami-xxxxxxxxx \
  --instance-type g4dn.xlarge \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --iam-instance-profile Name=YourInstanceProfileWithCloudWatchPermissions

# SSH into the instance
ssh -i your-key.pem ubuntu@instance-ip

# Verify NVIDIA drivers
nvidia-smi

# Verify Docker with GPU
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi

# Start CloudWatch agent (includes GPU monitoring)
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json

# Check CloudWatch agent status
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a query -m ec2

# View GPU metrics in CloudWatch (CWAgent namespace)
# Dimensions: Index (GPU ID), Name (GPU type), Architecture
```

## Required IAM Permissions

### For Packer Build (AWS Credentials in .secrets)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "iam:PassRole"
      ],
      "Resource": "*"
    },
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
  ]
}
```

### For Instances Launched from AMI
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
```
