#!/bin/bash

# deploy.sh - Deploy image processor to EKS cluster
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting deployment to EKS cluster...${NC}"

# Function to get EKS cluster name from terraform state
get_cluster_name() {
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
        echo "Please ensure Terraform has been applied and state file exists"
        exit 1
    fi
    
    # Extract cluster name from terraform state
    local cluster_name=$(grep -o '"cluster_name"[^,]*' "$state_file" | cut -d'"' -f4 | head -1)
    
    if [ -z "$cluster_name" ]; then
        echo -e "${RED}❌ Error: Could not find EKS cluster name in terraform state${NC}"
        exit 1
    fi
    
    echo "$cluster_name"
}

# Function to get AWS region from terraform state
get_aws_region() {
    local state_file=""
    
    # Search for terraform.tfstate in multiple locations
    if [ -f "terraform.tfstate" ]; then
        state_file="terraform.tfstate"
    elif [ -f "infra/terraform.tfstate" ]; then
        state_file="infra/terraform.tfstate"
    elif [ -f "../infra/terraform.tfstate" ]; then
        state_file="../infra/terraform.tfstate"
    fi
    
    # Extract region from terraform state
    local region=$(grep -o '"region"[^,]*' "$state_file" | cut -d'"' -f4 | head -1)
    
    if [ -z "$region" ]; then
        # Default to us-east-1 if not found
        region="us-east-1"
    fi
    
    echo "$region"
}

# Function to find deployment.yaml
find_deployment_yaml() {
    if [ -f "deployment.yaml" ]; then
        echo "deployment.yaml"
    elif [ -f "eks-app/deployment.yaml" ]; then
        echo "eks-app/deployment.yaml"
    elif [ -f "../eks-app/deployment.yaml" ]; then
        echo "../eks-app/deployment.yaml"
    else
        echo -e "${RED}❌ Error: deployment.yaml not found${NC}"
        echo "Please ensure deployment.yaml exists in eks-app/ directory"
        exit 1
    fi
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ Error: kubectl is not installed${NC}"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if aws CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Get cluster information from terraform state
echo -e "${BLUE}📋 Reading cluster information from terraform state...${NC}"
CLUSTER_NAME=$(get_cluster_name)
AWS_REGION=$(get_aws_region)
DEPLOYMENT_FILE=$(find_deployment_yaml)

echo -e "${GREEN}✅ Found cluster: $CLUSTER_NAME in region: $AWS_REGION${NC}"

# Update kubeconfig to connect to EKS cluster
echo -e "${BLUE}🔧 Updating kubeconfig for EKS cluster...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Failed to update kubeconfig${NC}"
    echo "Please check your AWS credentials and cluster permissions"
    exit 1
fi

echo -e "${GREEN}✅ Kubeconfig updated successfully${NC}"

# Verify cluster connection
echo -e "${BLUE}🔍 Verifying cluster connection...${NC}"
kubectl cluster-info &> /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Cannot connect to EKS cluster${NC}"
    echo "Please check your kubeconfig and cluster status"
    exit 1
fi

echo -e "${GREEN}✅ Connected to EKS cluster${NC}"

# Apply the deployment
echo -e "${BLUE}🚀 Applying Kubernetes deployment...${NC}"
kubectl apply -f "$DEPLOYMENT_FILE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Failed to apply deployment${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment applied successfully${NC}"

# Wait for deployment to be ready
echo -e "${BLUE}⏳ Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/image-processor

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Deployment did not become ready within 5 minutes${NC}"
    echo "Checking deployment status..."
else
    echo -e "${GREEN}✅ Deployment is ready!${NC}"
fi

# Show deployment status
echo -e "${BLUE}📊 Deployment Status:${NC}"
kubectl get deployment image-processor
echo ""

echo -e "${BLUE}🎯 Pod Status:${NC}"
kubectl get pods -l app=image-processor
echo ""

echo -e "${BLUE}📋 Service Status:${NC}"
kubectl get service image-processor
echo ""

# Show recent pod logs
echo -e "${BLUE}📝 Recent Pod Logs:${NC}"
POD_NAME=$(kubectl get pods -l app=image-processor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$POD_NAME" ]; then
    echo "Showing logs for pod: $POD_NAME"
    kubectl logs "$POD_NAME" --tail=20 || echo "No logs available yet"
else
    echo "No pods found for image-processor deployment"
fi

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo -e "${BLUE}💡 Useful commands:${NC}"
echo "  View pods:        kubectl get pods -l app=image-processor"
echo "  View logs:        kubectl logs -l app=image-processor -f"
echo "  Restart deployment: kubectl rollout restart deployment image-processor"
echo "  Delete deployment: kubectl delete -f $DEPLOYMENT_FILE"
echo "  Scale deployment: kubectl scale deployment image-processor --replicas=2"
