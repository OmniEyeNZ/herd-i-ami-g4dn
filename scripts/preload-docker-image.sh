#!/bin/bash
set -e

echo "=========================================="
echo "Pre-loading Docker Image"
echo "=========================================="

# Check if DOCKER_IMAGE is set
if [ -z "$DOCKER_IMAGE" ]; then
    echo "No Docker image specified via DOCKER_IMAGE environment variable. Skipping pre-load."
    echo "To pre-load an image, set the docker_image variable when running packer."
    exit 0
fi

echo "Docker image to pre-load: $DOCKER_IMAGE"

# Check if this is an ECR image
if [[ "$DOCKER_IMAGE" == *.dkr.ecr.*.amazonaws.com/* ]]; then
    echo "Detected ECR image. Authenticating with ECR..."

    # Extract region from ECR URL
    ECR_REGION=$(echo "$DOCKER_IMAGE" | sed -n 's/.*\.dkr\.ecr\.\([^.]*\)\.amazonaws\.com.*/\1/p')

    if [ -z "$ECR_REGION" ]; then
        echo "ERROR: Could not extract AWS region from ECR URL"
        exit 1
    fi

    echo "ECR Region: $ECR_REGION"

    # Login to ECR
    aws ecr get-login-password --region "$ECR_REGION" | sudo docker login --username AWS --password-stdin "$(echo "$DOCKER_IMAGE" | cut -d'/' -f1)"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to authenticate with ECR"
        exit 1
    fi

    echo "Successfully authenticated with ECR"
fi

echo "Pulling Docker image: $DOCKER_IMAGE"
sudo docker pull "$DOCKER_IMAGE"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to pull Docker image"
    exit 1
fi

echo "Verifying image..."
sudo docker images | grep -E "REPOSITORY|${DOCKER_IMAGE%:*}"

# Optional: Save image size information
IMAGE_SIZE=$(sudo docker images "$DOCKER_IMAGE" --format "{{.Size}}")
echo "Image size: $IMAGE_SIZE"

# Logout from ECR if we logged in
if [[ "$DOCKER_IMAGE" == *.dkr.ecr.*.amazonaws.com/* ]]; then
    echo "Logging out from ECR..."
    sudo docker logout "$(echo "$DOCKER_IMAGE" | cut -d'/' -f1)" || true
fi

echo "=========================================="
echo "Docker image $DOCKER_IMAGE pre-loaded successfully!"
echo "=========================================="
