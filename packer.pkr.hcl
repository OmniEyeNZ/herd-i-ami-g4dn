# Packer Template for AWS G4dn GPU-enabled AMI
# with CloudWatch GPU monitoring and pre-loaded Docker image

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Data source to get the latest Deep Learning Base GPU AMI
data "amazon-ami" "base" {
  filters = {
    name                = var.source_ami_name_filter
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    state               = "available"
  }
  most_recent = true
  owners      = [var.source_ami_owner]
  region      = var.aws_region
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"
}

# Source configuration
source "amazon-ebs" "gpu_ami" {
  region        = var.aws_region
  source_ami    = data.amazon-ami.base.id
  instance_type = var.instance_type
  ssh_username  = var.ssh_username
  ami_name      = local.ami_name

  # Create temporary IAM instance profile for ECR access
  temporary_iam_instance_profile_policy_document {
    Statement {
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Statement {
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Version = "2012-10-17"
  }

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = var.volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
    delete_on_termination = true
  }

  tags = merge(
    var.tags,
    {
      "SourceAMI"   = data.amazon-ami.base.id
      "BuildDate"   = local.timestamp
      "BaseAMIName" = data.amazon-ami.base.name
    }
  )

  run_tags = {
    "Name" = "Packer Builder - ${local.ami_name}"
  }
}

# Build configuration
build {
  name    = "gpu-ami"
  sources = ["source.amazon-ebs.gpu_ami"]

  # Update system packages
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo apt-get install -y wget curl unzip jq awscli"
    ]
  }

  # Verify AWS CLI is available
  provisioner "shell" {
    inline = [
      "echo 'Verifying AWS CLI...'",
      "aws --version"
    ]
  }

  # Verify NVIDIA drivers and tools
  provisioner "shell" {
    inline = [
      "echo 'Verifying NVIDIA drivers...'",
      "nvidia-smi",
      "nvcc --version || echo 'CUDA compiler not found, but drivers are present'"
    ]
  }

  # Install Docker
  provisioner "shell" {
    script = "${path.root}/scripts/install-docker.sh"
  }

  # Install CloudWatch Agent
  provisioner "shell" {
    script = "${path.root}/scripts/install-cloudwatch-agent.sh"
  }

  # Upload CloudWatch configuration
  provisioner "file" {
    source      = "${path.root}/configs/cloudwatch-config.json"
    destination = "/tmp/cloudwatch-config.json"
  }

  # Configure GPU monitoring
  provisioner "shell" {
    script = "${path.root}/scripts/configure-gpu-monitoring.sh"
  }

  # Pre-load Docker image if specified
  provisioner "shell" {
    script = "${path.root}/scripts/preload-docker-image.sh"
    environment_vars = [
      "DOCKER_IMAGE=${var.docker_image}"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "history -c"
    ]
  }

  # Post-processor to create a manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
