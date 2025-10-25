#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine script directory and ensure we're in local-deployment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Check if we're already in local-deployment directory
if [[ "$(basename "$SCRIPT_DIR")" == "local-deployment" ]]; then
    cd "$SCRIPT_DIR"
    echo -e "${GREEN}✅ Running from local-deployment directory${NC}"
elif [[ -d "local-deployment" ]]; then
    cd local-deployment
    echo -e "${YELLOW}📁 Changed to local-deployment directory${NC}"
else
    echo -e "${RED}❌ Error: Cannot find local-deployment directory${NC}"
    echo -e "${YELLOW}Please run this script from the project root or local-deployment directory${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Bootstrapping Local GitHub Actions Testing Environment${NC}"
echo "========================================================="
echo ""

# Check if Docker is installed
echo -e "${YELLOW}🐳 Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo -e "${YELLOW}Please install Docker first:${NC}"
    echo "   - Ubuntu/Debian: sudo apt install docker.io"
    echo "   - macOS: Download Docker Desktop"
    echo "   - Windows: Download Docker Desktop"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo -e "${YELLOW}Please start Docker and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is installed and running${NC}"

# Create bin directory if it doesn't exist
echo -e "${YELLOW}📁 Creating bin directory...${NC}"
mkdir -p bin

# Check if act is already installed locally
if [ -f "bin/act" ]; then
    echo -e "${YELLOW}📋 act is already installed locally${NC}"
    CURRENT_VERSION=$(./bin/act --version 2>/dev/null | head -n1 || echo "unknown")
    echo -e "   Current version: ${BLUE}$CURRENT_VERSION${NC}"
    
    read -p "Do you want to reinstall/update act? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Skipping act installation${NC}"
        SKIP_ACT=true
    fi
fi

# Install act locally
if [ "$SKIP_ACT" != "true" ]; then
    echo -e "${YELLOW}⬇️  Downloading and installing act...${NC}"
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac
    
    # Get latest release info
    echo -e "${YELLOW}🔍 Getting latest act release info...${NC}"
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/nektos/act/releases/latest)
    VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        echo -e "${RED}❌ Failed to get latest version info${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📦 Installing act version: v$VERSION${NC}"
    
    # Download URL
    DOWNLOAD_URL="https://github.com/nektos/act/releases/download/v${VERSION}/act_${OS^}_${ARCH}.tar.gz"
    
    # Download act
    echo -e "${YELLOW}⬇️  Downloading from: $DOWNLOAD_URL${NC}"
    if ! curl -L -o bin/act.tar.gz "$DOWNLOAD_URL"; then
        echo -e "${RED}❌ Failed to download act${NC}"
        exit 1
    fi

    # Extract the binary
    echo -e "${YELLOW}📦 Extracting act binary...${NC}"
    if ! tar -xzf bin/act.tar.gz -C bin act; then
        echo -e "${RED}❌ Failed to extract act${NC}"
        exit 1
    fi

    # Clean up tarball
    rm bin/act.tar.gz

    # Make executable
    chmod +x bin/act
    
    echo -e "${GREEN}✅ act installed successfully${NC}"
fi

# Verify installation
echo -e "${YELLOW}🔍 Verifying act installation...${NC}"
ACT_VERSION=$(./bin/act --version 2>/dev/null | head -n1 || echo "Failed to get version")
echo -e "   Version: ${BLUE}$ACT_VERSION${NC}"

# Set up configuration files
echo -e "${YELLOW}📝 Setting up configuration files...${NC}"

# Check for .env file
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "${YELLOW}📋 Creating .env from .env.example${NC}"
        cp .env.example .env
        echo -e "${YELLOW}⚠️  Please edit .env with your actual values${NC}"
    else
        echo -e "${YELLOW}⚠️  .env.example not found, you'll need to create .env manually${NC}"
    fi
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

# Check for .secrets file
if [ ! -f ".secrets" ]; then
    if [ -f ".secrets.example" ]; then
        echo -e "${YELLOW}📋 Creating .secrets from .secrets.example${NC}"
        cp .secrets.example .secrets
        echo -e "${YELLOW}⚠️  Please edit .secrets with your actual values${NC}"
    else
        echo -e "${YELLOW}⚠️  .secrets.example not found, you'll need to create .secrets manually${NC}"
    fi
else
    echo -e "${GREEN}✅ .secrets file already exists${NC}"
fi

# Test act installation
echo -e "${YELLOW}🧪 Testing act installation...${NC}"
if ./bin/act --list &> /dev/null; then
    echo -e "${GREEN}✅ act is working correctly${NC}"
else
    echo -e "${RED}❌ act test failed${NC}"
    echo -e "${YELLOW}Try running: ./bin/act --help${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Bootstrap completed successfully!${NC}"
echo ""

# Ask if user wants to sync from AWS Secrets Manager
echo -e "${BLUE}🔄 AWS Secrets Manager Sync${NC}"
echo -e "${YELLOW}Would you like to download configuration from AWS Secrets Manager?${NC}"
echo -e "   This will overwrite your local .env and .secrets files"
echo -e "   with values from AWS Secrets Manager."
echo ""
read -p "Sync from AWS Secrets Manager? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Source the configuration files to get AWS credentials and environment
    if [ ! -f ".secrets" ] || [ ! -f ".env" ]; then
        echo -e "${RED}❌ .secrets or .env files not found${NC}"
        echo -e "${YELLOW}Please create these files with AWS credentials first${NC}"
        exit 1
    fi

    echo -e "${YELLOW}📥 Reading local configuration...${NC}"

    # Extract AWS credentials from .secrets
    AWS_ACCESS_KEY_ID=$(grep -E '^AWS_ACCESS_KEY_ID=' .secrets | cut -d'=' -f2)
    AWS_SECRET_ACCESS_KEY=$(grep -E '^AWS_SECRET_ACCESS_KEY=' .secrets | cut -d'=' -f2)

    # Extract AWS region and environment from .env
    # Use AWS_REGION_CODE if available, otherwise AWS_REGION
    AWS_REGION_CODE=$(grep -E '^AWS_REGION_CODE=' .env | cut -d'=' -f2)
    AWS_REGION=$(grep -E '^AWS_REGION=' .env | cut -d'=' -f2)
    ENVIRONMENT=$(grep -E '^ENVIRONMENT_NAME=' .env | cut -d'=' -f2)

    # Use AWS_REGION_CODE if set, otherwise try to map AWS_REGION, or default
    if [ -n "$AWS_REGION_CODE" ]; then
        AWS_REGION="$AWS_REGION_CODE"
    elif [ "$AWS_REGION" == "Sydney" ]; then
        AWS_REGION="ap-southeast-2"
    elif [ "$AWS_REGION" == "Oregon" ]; then
        AWS_REGION="us-west-2"
    fi

    # Default values if not found
    AWS_REGION=${AWS_REGION:-ap-southeast-2}
    ENVIRONMENT=${ENVIRONMENT:-development}

    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo -e "${RED}❌ AWS credentials not found in .secrets file${NC}"
        echo -e "${YELLOW}Please add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to .secrets${NC}"
        exit 1
    fi

    echo -e "${BLUE}   Environment: $ENVIRONMENT${NC}"
    echo -e "${BLUE}   AWS Region: $AWS_REGION${NC}"
    echo ""

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed${NC}"
        echo -e "${YELLOW}Installing AWS CLI...${NC}"
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip -q /tmp/awscliv2.zip -d /tmp/
        sudo /tmp/aws/install
        rm -rf /tmp/aws /tmp/awscliv2.zip
        echo -e "${GREEN}✅ AWS CLI installed${NC}"
    fi

    echo -e "${YELLOW}☁️  Downloading configuration from AWS Secrets Manager...${NC}"

    # Export AWS credentials for AWS CLI
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_REGION

    # Create new .secrets file header
    echo "# Downloaded from AWS Secrets Manager" > .secrets
    echo "# Environment: $ENVIRONMENT" >> .secrets
    echo "# Date: $(date)" >> .secrets
    echo "" >> .secrets

    # List all secrets in AWS Secrets Manager
    echo -e "${YELLOW}   Listing secrets in AWS Secrets Manager...${NC}"

    # Get list of all secrets as an array
    mapfile -t SECRET_ARRAY < <(aws secretsmanager list-secrets --output json | jq -r '.SecretList[].Name')

    if [ ${#SECRET_ARRAY[@]} -eq 0 ]; then
        echo -e "${RED}❌ Failed to list secrets or no secrets found${NC}"
        echo -e "${YELLOW}Continuing with existing .secrets file...${NC}"
    else
        echo -e "${GREEN}   Found ${#SECRET_ARRAY[@]} secrets${NC}"
        SECRET_COUNT=0

        # Download each secret individually
        # Disable exit on error for the loop
        set +e
        for SECRET_NAME in "${SECRET_ARRAY[@]}"; do
            if [ -z "$SECRET_NAME" ]; then
                continue
            fi

            echo -e "${YELLOW}   Fetching: $SECRET_NAME${NC}"

            # Get the secret value
            SECRET_VALUE=$(aws secretsmanager get-secret-value \
                --secret-id "$SECRET_NAME" \
                --query SecretString \
                --output text 2>&1)

            FETCH_STATUS=$?

            if [ $FETCH_STATUS -eq 0 ]; then
                # Use the secret name exactly as it appears in AWS
                echo "${SECRET_NAME}=${SECRET_VALUE}" >> .secrets
                echo -e "${GREEN}   ✓ Downloaded $SECRET_NAME${NC}"
                SECRET_COUNT=$((SECRET_COUNT + 1))
            else
                echo -e "${RED}   ❌ Failed to fetch $SECRET_NAME${NC}"
            fi
        done
        # Re-enable exit on error
        set -e

        echo ""

        if [ $SECRET_COUNT -gt 0 ]; then
            echo -e "${GREEN}✅ Downloaded $SECRET_COUNT secrets from AWS Secrets Manager${NC}"
        else
            echo -e "${YELLOW}⚠️  No secrets found with ManagedBy=GitHub-Actions tag${NC}"
            echo -e "${YELLOW}Continuing with existing .secrets file...${NC}"
        fi

        # Note about AWS credentials
        echo "" >> .secrets
        echo "# Note: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be added manually" >> .secrets
    fi

    echo ""
    echo -e "${YELLOW}☁️  Downloading environment variables from AWS SSM Parameter Store...${NC}"

    # Create new .env file header
    echo "# Downloaded from AWS SSM Parameter Store" > .env
    echo "# Environment: $ENVIRONMENT" >> .env
    echo "# Date: $(date)" >> .env
    echo "" >> .env

    # List all parameters that start with GH_
    echo -e "${YELLOW}   Listing parameters starting with GH_...${NC}"

    # Get list of all parameters starting with GH_
    mapfile -t PARAM_ARRAY < <(aws ssm describe-parameters \
        --parameter-filters "Key=Name,Option=BeginsWith,Values=GH_" \
        --output json | jq -r '.Parameters[].Name')

    if [ ${#PARAM_ARRAY[@]} -eq 0 ]; then
        echo -e "${RED}❌ No parameters found starting with GH_${NC}"
        echo -e "${YELLOW}Creating empty .env file...${NC}"
    else
        echo -e "${GREEN}   Found ${#PARAM_ARRAY[@]} parameters${NC}"
        PARAM_COUNT=0

        # Download each parameter individually
        # Disable exit on error for the loop
        set +e
        for PARAM_NAME in "${PARAM_ARRAY[@]}"; do
            if [ -z "$PARAM_NAME" ]; then
                continue
            fi

            echo -e "${YELLOW}   Fetching: $PARAM_NAME${NC}"

            # Get the parameter value
            PARAM_VALUE=$(aws ssm get-parameter \
                --name "$PARAM_NAME" \
                --with-decryption \
                --query Parameter.Value \
                --output text 2>&1)

            FETCH_STATUS=$?

            if [ $FETCH_STATUS -eq 0 ]; then
                # Strip GH_ prefix from parameter name
                ENV_VAR_NAME="${PARAM_NAME#GH_}"
                echo "${ENV_VAR_NAME}=${PARAM_VALUE}" >> .env
                echo -e "${GREEN}   ✓ Downloaded $PARAM_NAME -> $ENV_VAR_NAME${NC}"
                PARAM_COUNT=$((PARAM_COUNT + 1))
            else
                echo -e "${RED}   ❌ Failed to fetch $PARAM_NAME${NC}"
            fi
        done
        # Re-enable exit on error
        set -e

        echo ""

        if [ $PARAM_COUNT -gt 0 ]; then
            echo -e "${GREEN}✅ Downloaded $PARAM_COUNT parameters from SSM Parameter Store${NC}"
        else
            echo -e "${YELLOW}⚠️  No parameters were downloaded${NC}"
        fi
    fi

    # Unset AWS credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_REGION

    echo ""
    echo -e "${GREEN}✅ Configuration synced from AWS Secrets Manager and SSM Parameter Store${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping AWS Secrets Manager sync${NC}"
fi

echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "   1. Review ${YELLOW}.env${NC} and ${YELLOW}.secrets${NC} files"
echo -e "   2. Test with: ${YELLOW}./bin/act --list${NC}"
echo -e "   3. Run Deploy.yml workflow test (see README.md for examples)"
echo ""
echo -e "${YELLOW}💡 Available commands:${NC}"
echo -e "   ${BLUE}./bin/act --list${NC}                              - List available workflows"
echo -e "   ${BLUE}./bin/act --help${NC}                              - Show act help"
echo -e "   ${BLUE}./bin/act workflow_dispatch -W ../.github/workflows/Deploy.yml${NC}"
echo -e "     ${BLUE}--input environment=development${NC}"
echo -e "     ${BLUE}--input terraform_action=plan${NC}"
echo -e "     ${BLUE}--input target_repository=herd-i-iac-modules${NC}  - Test Deploy.yml workflow"
echo ""
echo -e "For more examples, see: ${YELLOW}README.md${NC}"