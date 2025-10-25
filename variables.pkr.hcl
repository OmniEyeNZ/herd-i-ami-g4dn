# Packer Variables for G4dn GPU AMI

variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI in"
  default     = "us-east-1"
}

variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the AMI name"
  default     = "g4dn-gpu-monitored"
}

variable "instance_type" {
  type        = string
  description = "Instance type to use for building (must be G4dn)"
  default     = "g4dn.xlarge"
}

variable "source_ami_owner" {
  type        = string
  description = "AMI owner (amazon for AWS Deep Learning AMIs)"
  default     = "amazon"
}

variable "source_ami_name_filter" {
  type        = string
  description = "Filter for source AMI name"
  default     = "Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 24.04) ?????????"
}

variable "docker_image" {
  type        = string
  description = "Docker image to pre-load (e.g., nvidia/cuda:12.4.0-base-ubuntu24.04)"
  default     = ""
}

variable "ssh_username" {
  type        = string
  description = "SSH username for Ubuntu AMI"
  default     = "ubuntu"
}

variable "volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 100
}

variable "tags" {
  type = map(string)
  description = "Tags to apply to the AMI"
  default = {
    "Name"        = "G4dn GPU Monitored AMI"
    "Environment" = "production"
    "ManagedBy"   = "Packer"
  }
}
