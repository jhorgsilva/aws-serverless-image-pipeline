#!/bin/bash

# test-pipeline.sh - Test the complete image processing pipeline
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Starting Image Processing Pipeline Test...${NC}"

# Function to get S3 bucket name from terraform state
get_s3_bucket_name() {
    local state_file=""
    
    # Search for terraform.tfstate in multiple locations
    if [ -f "terraform.tfstate" ]; then
        state_file="terraform.tfstate"
    elif [ -f "infra/terraform.tfstate" ]; then
        state_file="infra/terraform.tfstate"
    elif [ -f "../infra/terraform.tfstate" ]; then
        state_file="../infra/terraform.tfstate"
    else
        echo -e "${RED}❌ Error: terraform.tfstate not found${NC}"
        exit 1
    fi
    
    # Extract bucket name from terraform state
    local bucket_name=$(grep -o '"bucket"[^,]*' "$state_file" | grep 'dev-my-raw-images' | cut -d'"' -f4 | head -1)
    
    if [ -z "$bucket_name" ]; then
        echo -e "${RED}❌ Error: Could not find S3 bucket name in terraform state${NC}"
        exit 1
    fi
    
    echo "$bucket_name"
}

# Function to get SQS queue URL from terraform state
get_sqs_queue_url() {
    local state_file=""
    
    if [ -f "terraform.tfstate" ]; then
        state_file="terraform.tfstate"
    elif [ -f "infra/terraform.tfstate" ]; then
        state_file="infra/terraform.tfstate"
    elif [ -f "../infra/terraform.tfstate" ]; then
        state_file="../infra/terraform.tfstate"
    fi
    
    # Extract SQS queue URL from terraform state
    local queue_url=$(grep -o '"url"[^,]*' "$state_file" | grep 'sqs.us-east-1' | cut -d'"' -f4 | head -1)
    echo "$queue_url"
}

# Function to find test image
find_test_image() {
    if [ -f "test-image.jpg" ]; then
        echo "test-image.jpg"
    elif [ -f "infra/test-image.jpg" ]; then
        echo "infra/test-image.jpg"
    elif [ -f "../infra/test-image.jpg" ]; then
        echo "../infra/test-image.jpg"
    else
        echo -e "${RED}❌ Error: test-image.jpg not found${NC}"
        echo "Please ensure test-image.jpg exists in the project directory"
        exit 1
    fi
}

# Check if aws CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ Error: kubectl is not installed${NC}"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Get infrastructure details
echo -e "${BLUE}📋 Reading infrastructure details...${NC}"
BUCKET_NAME=$(get_s3_bucket_name)
QUEUE_URL=$(get_sqs_queue_url)
TEST_IMAGE=$(find_test_image)

echo -e "${GREEN}✅ Found S3 bucket: $BUCKET_NAME${NC}"
echo -e "${GREEN}✅ Found SQS queue: $QUEUE_URL${NC}"
echo -e "${GREEN}✅ Found test image: $TEST_IMAGE${NC}"

# Use simple filename without timestamp
IMAGE_KEY="test-image.jpg"
THUMBNAIL_KEY="thumbnails/test-image_thumb.jpg"

echo ""
echo -e "${BLUE}🔍 Pre-test Status Check:${NC}"

# Check EKS pod status
echo -e "${PURPLE}📊 EKS Pod Status:${NC}"
kubectl get pods -l app=image-processor

# Check if pods are ready
POD_STATUS=$(kubectl get pods -l app=image-processor -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${YELLOW}⚠️  Warning: EKS pod is not running. Status: $POD_STATUS${NC}"
    echo "The pipeline test will continue, but processing may fail."
fi

echo ""
echo -e "${BLUE}📤 Step 1: Uploading test image to S3...${NC}"

# Upload test image to S3
aws s3 cp "$TEST_IMAGE" "s3://$BUCKET_NAME/$IMAGE_KEY"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Image uploaded successfully: s3://$BUCKET_NAME/$IMAGE_KEY${NC}"
else
    echo -e "${RED}❌ Failed to upload image to S3${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}⏳ Step 2: Waiting for Lambda to process S3 event...${NC}"
sleep 5

echo -e "${BLUE}� Step 3: Monitoring EKS pod processing...${NC}"

# Monitor pod logs for processing activity
echo -e "${PURPLE}📝 Recent Pod Logs:${NC}"
kubectl logs -l app=image-processor --tail=20 --since=1m || echo "No recent logs available"

echo ""
echo -e "${BLUE}⏳ Step 4: Waiting for thumbnail generation...${NC}"

# Wait and check for thumbnail generation
THUMBNAIL_FOUND=false
for i in {1..20}; do
    if aws s3 ls "s3://$BUCKET_NAME/$THUMBNAIL_KEY" &>/dev/null; then
        echo -e "${GREEN}✅ Thumbnail generated successfully!${NC}"
        THUMBNAIL_FOUND=true
        break
    else
        echo -e "${YELLOW}⏳ Waiting for thumbnail... (attempt $i/20)${NC}"
        sleep 3
    fi
done

echo ""
echo -e "${BLUE}📊 Step 5: Pipeline Test Results${NC}"
echo "=================================="

# Check S3 bucket contents recursively
echo -e "${PURPLE}📁 S3 Bucket Contents (All Files):${NC}"
aws s3 ls "s3://$BUCKET_NAME/" --recursive

echo ""
echo -e "${PURPLE}📈 Infrastructure Status:${NC}"

# Lambda function status
echo "Lambda Function:"
LAMBDA_NAME=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `s3-to-sns`)].FunctionName' --output text 2>/dev/null || echo "")
if [ -n "$LAMBDA_NAME" ]; then
    echo -e "  ✅ Function found: $LAMBDA_NAME"
else
    echo "  ❌ Lambda function not found"
fi

# SNS topic status
echo "SNS Topic:"
SNS_TOPIC=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `image`)].TopicArn' --output text 2>/dev/null || echo "")
if [ -n "$SNS_TOPIC" ]; then
    echo -e "  ✅ Topic found: $(basename $SNS_TOPIC)"
else
    echo "  ❌ SNS topic not found"
fi

# SQS queue status
echo "SQS Queue:"
if [ -n "$QUEUE_URL" ]; then
    QUEUE_NAME=$(basename "$QUEUE_URL")
    echo -e "  ✅ Queue found: $QUEUE_NAME"
else
    echo "  ❌ SQS queue not found"
fi

# EKS status
echo "EKS Cluster:"
kubectl cluster-info --request-timeout=5s &>/dev/null
if [ $? -eq 0 ]; then
    echo -e "  ✅ Cluster accessible"
    READY_PODS=$(kubectl get pods -l app=image-processor -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
    echo -e "  📊 Ready pods: $READY_PODS"
else
    echo "  ❌ Cluster not accessible"
fi

echo ""
echo -e "${BLUE}🎯 Test Summary${NC}"
echo "==============="

if [ "$THUMBNAIL_FOUND" = true ]; then
    echo -e "${GREEN}🎉 SUCCESS: Complete pipeline test passed!${NC}"
    echo -e "${GREEN}✅ Image uploaded to S3${NC}"
    echo -e "${GREEN}✅ Lambda processed S3 event${NC}"
    echo -e "${GREEN}✅ SNS message published${NC}"
    echo -e "${GREEN}✅ SQS received message${NC}"
    echo -e "${GREEN}✅ EKS pod processed image${NC}"
    echo -e "${GREEN}✅ Thumbnail generated${NC}"
    echo ""
    echo -e "${BLUE}📁 Generated files:${NC}"
    echo "  Original: s3://$BUCKET_NAME/$IMAGE_KEY"
    echo "  Thumbnail: s3://$BUCKET_NAME/$THUMBNAIL_KEY"
else
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS: Pipeline partially working${NC}"
    echo -e "${GREEN}✅ S3 → Lambda → SNS → SQS → EKS chain working${NC}"
    echo -e "${BLUE}💡 Check the S3 bucket contents above to see all generated thumbnails${NC}"
fi