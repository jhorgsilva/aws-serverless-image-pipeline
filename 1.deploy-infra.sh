#!/bin/bash

# deploy-infra.sh - Deploy Image Processing Pipeline Infrastructure
# This script initializes and applies the Terraform infrastructure

set -e  # Exit on any error

echo "🚀 Deploying Image Processing Pipeline Infrastructure..."
echo "===================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    print_error "Please run 'aws configure' to set up your credentials"
    exit 1
fi

print_success "AWS credentials verified"

# Get current AWS account and region
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

print_status "Deploying to AWS Account: $AWS_ACCOUNT"
print_status "Deploying to AWS Region: $AWS_REGION"

# Change to infra directory
cd "$(dirname "$0")/infra" || {
    print_error "Could not change to infra directory"
    exit 1
}

print_status "Changed to infra directory: $(pwd)"

# Step 1: Initialize Terraform
print_status "Step 1: Initializing Terraform..."

if terraform init; then
    print_success "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi

# Step 2: Validate Terraform configuration
print_status "Step 2: Validating Terraform configuration..."

if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration validation failed"
    exit 1
fi

# Step 3: Plan infrastructure
print_status "Step 3: Planning infrastructure changes..."

if terraform plan -out=tfplan; then
    print_success "Terraform plan completed successfully"
else
    print_error "Terraform plan failed"
    exit 1
fi

# Step 4: Apply infrastructure
print_status "Step 4: Applying infrastructure changes..."
print_warning "This will create AWS resources that may incur charges"

# Ask for confirmation
read -p "Do you want to proceed with the deployment? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_status "Deployment cancelled by user"
    rm -f tfplan
    exit 0
fi

print_status "Applying Terraform configuration..."

if terraform apply tfplan; then
    print_success "Infrastructure deployed successfully!"
else
    print_error "Terraform apply failed"
    rm -f tfplan
    exit 1
fi

# Clean up plan file
rm -f tfplan

# Step 5: Display outputs
print_status "Step 5: Displaying infrastructure outputs..."

echo ""
echo "📋 Infrastructure Details:"
echo "========================="

terraform output

echo ""
print_success "🎉 Infrastructure deployment completed!"
echo "===================================================="

# Show next steps
echo ""
print_status "Next Steps:"
print_status "  1. Build and deploy the Docker image: ./deploy-to-ecr.sh"
print_status "  2. Test the pipeline: ./test-pipeline.sh"
print_status "  3. Monitor with: kubectl get pods"
print_status "  4. Clean up when done: ./cleanup.sh"
echo ""

# Show important URLs/info
EKS_CLUSTER=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "N/A")
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "N/A")
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "N/A")

echo "🔗 Quick Reference:"
echo "  EKS Cluster: $EKS_CLUSTER"
echo "  S3 Bucket: $S3_BUCKET"
echo "  ECR Repository: $ECR_REPO"
echo ""

print_warning "Remember to clean up resources when done to avoid charges: ./cleanup.sh"
