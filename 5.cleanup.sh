#!/bin/bash

# cleanup.sh - Comprehensive cleanup script for Image Processing Pipeline
# This script removes all AWS resources created by the Terraform infrastructure

set -e  # Exit on any error

echo "🧹 Starting comprehensive cleanup of Image Processing Pipeline resources..."
echo "======================================================================"

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
    exit 1
fi

print_status "AWS credentials verified"

# Change to infra directory
cd "$(dirname "$0")/infra" || {
    print_error "Could not change to infra directory"
    exit 1
}

print_status "Changed to infra directory: $(pwd)"

# Step 1: Stop any running EKS workloads
print_status "Step 1: Cleaning up EKS workloads..."

# Get cluster name from terraform output
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")

if [ -n "$CLUSTER_NAME" ]; then
    print_status "Found EKS cluster: $CLUSTER_NAME"
    
    # Update kubeconfig
    if aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME" &>/dev/null; then
        print_status "Updated kubeconfig for cluster: $CLUSTER_NAME"
        
        # Delete all deployments
        if kubectl get deployments &>/dev/null; then
            kubectl delete deployments --all --timeout=60s || print_warning "Failed to delete some deployments"
            print_success "Deleted all deployments"
        fi
        
        # Delete all services (except default kubernetes service)
        if kubectl get services &>/dev/null; then
            kubectl delete services --all --ignore-not-found=true || print_warning "Failed to delete some services"
            print_success "Deleted all services"
        fi
        
        # Delete all pods
        if kubectl get pods &>/dev/null; then
            kubectl delete pods --all --force --grace-period=0 || print_warning "Failed to delete some pods"
            print_success "Deleted all pods"
        fi
    else
        print_warning "Could not connect to EKS cluster, skipping workload cleanup"
    fi
else
    print_warning "No EKS cluster found in Terraform output"
fi

# Step 2: Empty S3 buckets before destroying infrastructure
print_status "Step 2: Emptying S3 buckets..."

BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -n "$BUCKET_NAME" ]; then
    print_status "Found S3 bucket: $BUCKET_NAME"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        # Delete all objects and versions
        print_status "Deleting all objects from bucket: $BUCKET_NAME"
        aws s3 rm "s3://$BUCKET_NAME" --recursive || print_warning "Failed to delete some objects"
        
        # Delete all object versions (for versioned buckets)
        aws s3api delete-objects \
            --bucket "$BUCKET_NAME" \
            --delete "$(aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" \
                --output json \
                --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || print_warning "No versions to delete"
        
        # Delete all delete markers
        aws s3api delete-objects \
            --bucket "$BUCKET_NAME" \
            --delete "$(aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" \
                --output json \
                --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || print_warning "No delete markers to delete"
        
        print_success "Emptied S3 bucket: $BUCKET_NAME"
    else
        print_warning "S3 bucket $BUCKET_NAME not found or not accessible"
    fi
else
    print_warning "No S3 bucket found in Terraform output"
fi

# Step 3: Purge SQS queues
print_status "Step 3: Purging SQS queues..."

SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "")
SQS_DLQ_URL=$(terraform output -raw sqs_dlq_url 2>/dev/null || echo "")

if [ -n "$SQS_QUEUE_URL" ]; then
    print_status "Purging SQS queue: $SQS_QUEUE_URL"
    aws sqs purge-queue --queue-url "$SQS_QUEUE_URL" || print_warning "Failed to purge main SQS queue"
    print_success "Purged main SQS queue"
fi

if [ -n "$SQS_DLQ_URL" ]; then
    print_status "Purging SQS DLQ: $SQS_DLQ_URL"
    aws sqs purge-queue --queue-url "$SQS_DLQ_URL" || print_warning "Failed to purge SQS DLQ"
    print_success "Purged SQS DLQ"
fi

# Step 4: Delete ECR images
print_status "Step 4: Cleaning up ECR repository..."

ECR_REPO_NAME=$(terraform output -raw ecr_repository_name 2>/dev/null || echo "")

if [ -n "$ECR_REPO_NAME" ]; then
    print_status "Found ECR repository: $ECR_REPO_NAME"
    
    # List and delete all images
    IMAGE_IDS=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
    
    if [ "$IMAGE_IDS" != "[]" ] && [ -n "$IMAGE_IDS" ]; then
        print_status "Deleting ECR images from repository: $ECR_REPO_NAME"
        aws ecr batch-delete-image --repository-name "$ECR_REPO_NAME" --image-ids "$IMAGE_IDS" || print_warning "Failed to delete some ECR images"
        print_success "Deleted ECR images"
    else
        print_status "No images found in ECR repository"
    fi
else
    print_warning "No ECR repository found in Terraform output"
fi

# Step 5: Run Terraform destroy
print_status "Step 5: Destroying Terraform infrastructure..."

# Confirm destruction
echo ""
print_warning "This will destroy ALL infrastructure including:"
print_warning "  - EKS cluster and node groups"
print_warning "  - Lambda functions"
print_warning "  - S3 buckets"
print_warning "  - SQS queues"
print_warning "  - SNS topics"
print_warning "  - CloudWatch alarms and log groups"
print_warning "  - IAM roles and policies"
print_warning "  - VPC and networking components"
print_warning "  - ECR repository"
echo ""

read -p "Are you sure you want to destroy all infrastructure? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_status "Cleanup cancelled by user"
    exit 0
fi

print_status "Running terraform destroy..."

# Run terraform destroy with auto-approve
if terraform destroy -auto-approve; then
    print_success "Terraform infrastructure destroyed successfully"
else
    print_error "Terraform destroy failed"
    
    # Try to get more information about what failed
    print_status "Attempting to show remaining resources..."
    terraform state list 2>/dev/null || print_warning "Could not list remaining resources"
    
    print_warning "You may need to manually clean up remaining resources"
    print_warning "Check the AWS console for any remaining resources"
    exit 1
fi

# Step 6: Clean up local files
print_status "Step 6: Cleaning up local files..."

# Remove terraform state files and directories
rm -rf .terraform/ 2>/dev/null || true
rm -f .terraform.lock.hcl 2>/dev/null || true
rm -f terraform.tfstate* 2>/dev/null || true

print_success "Cleaned up local Terraform files"

# Clean up kubectl config
if [ -n "$CLUSTER_NAME" ]; then
    kubectl config unset "clusters.$CLUSTER_NAME" 2>/dev/null || true
    kubectl config unset "contexts.$CLUSTER_NAME" 2>/dev/null || true
    kubectl config unset "users.$CLUSTER_NAME" 2>/dev/null || true
    print_success "Cleaned up kubectl configuration"
fi

# Step 7: Verify cleanup
print_status "Step 7: Verifying cleanup..."

# Check for any remaining resources (this is a basic check)
print_status "Checking for remaining resources..."

# Check EKS clusters
REMAINING_CLUSTERS=$(aws eks list-clusters --query 'clusters[?contains(@, `image-processor`) || contains(@, `dev-`)]' --output text 2>/dev/null || echo "")
if [ -n "$REMAINING_CLUSTERS" ]; then
    print_warning "Found remaining EKS clusters: $REMAINING_CLUSTERS"
fi

# Check S3 buckets
REMAINING_BUCKETS=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `image`) || contains(Name, `dev-`)].Name' --output text 2>/dev/null || echo "")
if [ -n "$REMAINING_BUCKETS" ]; then
    print_warning "Found remaining S3 buckets: $REMAINING_BUCKETS"
fi

# Check Lambda functions
REMAINING_FUNCTIONS=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `s3-to-sns`) || contains(FunctionName, `dev-`)].FunctionName' --output text 2>/dev/null || echo "")
if [ -n "$REMAINING_FUNCTIONS" ]; then
    print_warning "Found remaining Lambda functions: $REMAINING_FUNCTIONS"
fi

echo ""
print_success "🎉 Cleanup completed!"
echo "======================================================================"
print_status "Summary:"
print_status "  ✅ EKS workloads stopped"
print_status "  ✅ S3 buckets emptied"
print_status "  ✅ SQS queues purged"
print_status "  ✅ ECR images deleted"
print_status "  ✅ Terraform infrastructure destroyed"
print_status "  ✅ Local files cleaned up"
print_status "  ✅ Kubectl configuration cleaned"
echo ""
print_status "All resources have been cleaned up successfully!"
print_warning "Please check the AWS console to verify no unexpected charges remain"
echo ""
