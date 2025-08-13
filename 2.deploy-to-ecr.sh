#!/bin/bash

# ECR Build and Push Script
# This script builds the Docker image and pushes it to ECR

set -e  # Exit on error

# Configuration
REGION=${AWS_REGION:-"us-east-1"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}
IMAGE_NAME="${ENVIRONMENT}-image-processor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists aws; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    print_status "Prerequisites check completed"
}

# Get ECR repository URL from Terraform outputs
get_ecr_url() {
    print_status "Getting ECR repository URL from Terraform..."
    
    # Look for terraform.tfstate in current directory or infra directory
    if [ -f "terraform.tfstate" ]; then
        TERRAFORM_DIR="."
    elif [ -f "infra/terraform.tfstate" ]; then
        TERRAFORM_DIR="infra"
    elif [ -f "../infra/terraform.tfstate" ]; then
        TERRAFORM_DIR="../infra"
    else
        print_error "terraform.tfstate not found. Please run 'terraform apply' first"
        print_error "Looked in: ., infra/, ../infra/"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null)
    cd - > /dev/null
    
    if [ -z "$ECR_URL" ]; then
        print_error "Could not get ECR repository URL from Terraform outputs"
        exit 1
    fi
    
    print_status "ECR URL: $ECR_URL"
}

# Login to ECR
ecr_login() {
    print_status "Logging into ECR..."
    
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URL"
    
    if [ $? -eq 0 ]; then
        print_status "Successfully logged into ECR"
    else
        print_error "Failed to login to ECR"
        exit 1
    fi
}

# Build Docker image
build_image() {
    print_status "Building Docker image..."
    
    # Look for Dockerfile in current directory or eks-app directory
    if [ -f "Dockerfile" ]; then
        DOCKER_DIR="."
    elif [ -f "eks-app/Dockerfile" ]; then
        DOCKER_DIR="eks-app"
    elif [ -f "../eks-app/Dockerfile" ]; then
        DOCKER_DIR="../eks-app"
    else
        print_error "Dockerfile not found"
        print_error "Looked in: ., eks-app/, ../eks-app/"
        exit 1
    fi
    
    cd "$DOCKER_DIR"
    docker build -t "$IMAGE_NAME:latest" .
    cd - > /dev/null
    
    if [ $? -eq 0 ]; then
        print_status "Successfully built image: $IMAGE_NAME:latest"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Tag and push image to ECR
push_image() {
    print_status "Tagging and pushing image to ECR..."
    
    # Tag with latest
    docker tag "$IMAGE_NAME:latest" "$ECR_URL:latest"
    
    # Tag with timestamp for versioning
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    docker tag "$IMAGE_NAME:latest" "$ECR_URL:$TIMESTAMP"
    
    # Push both tags
    print_status "Pushing $ECR_URL:latest"
    docker push "$ECR_URL:latest"
    
    print_status "Pushing $ECR_URL:$TIMESTAMP"
    docker push "$ECR_URL:$TIMESTAMP"
    
    if [ $? -eq 0 ]; then
        print_status "Successfully pushed image to ECR"
        print_status "Image tags: latest, $TIMESTAMP"
        print_status ""
        print_status "🎉 Image is ready for deployment!"
        print_status "ECR Repository: $ECR_URL"
        print_status "Available tags: latest, $TIMESTAMP"
    else
        print_error "Failed to push image to ECR"
        exit 1
    fi
}

# Main execution
main() {
    print_status "Starting ECR build and push process..."
    
    check_prerequisites
    get_ecr_url
    ecr_login
    build_image
    push_image
    
    print_status "✅ Build and push completed successfully!"
}

# Handle script arguments
case "${1:-push}" in
    "build")
        check_prerequisites
        build_image
        ;;
    "push")
        main
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 {build|push|help}"
        echo ""
        echo "Commands:"
        echo "  build   - Only build the Docker image locally"
        echo "  push    - Build and push image to ECR (default)"
        echo "  help    - Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  AWS_REGION    - AWS region (default: us-east-1)"
        echo "  ENVIRONMENT   - Environment name (default: dev)"
        echo ""
        echo "The script will:"
        echo "  1. Build your Docker image from eks-app/"
        echo "  2. Get ECR URL from Terraform state"
        echo "  3. Login to ECR"
        echo "  4. Tag and push image with 'latest' and timestamp tags"
        ;;
    *)
        print_error "Unknown command: $1"
        print_error "Use '$0 help' for usage information"
        exit 1
        ;;
esac
