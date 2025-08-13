# Image Processing Pipeline on AWS

A complete serverless image processing pipeline built with AWS services, orchestrated by Terraform and deployed on Amazon EKS. This project automatically processes images uploaded to S3, creates thumbnails, and provides monitoring and alerting capabilities.

## 🏗️ Architecture Overview

This project implements a modern, scalable image processing pipeline using the following AWS services:

- **Amazon S3**: Storage for original images and generated thumbnails
- **AWS Lambda**: Triggered by S3 events to publish notifications
- **Amazon SNS**: Message publishing and error alerting
- **Amazon SQS**: Message queuing for reliable processing
- **Amazon EKS**: Kubernetes cluster running the image processing application
- **Amazon ECR**: Container registry for Docker images
- **Amazon CloudWatch**: Monitoring, logging, and alerting
- **AWS IAM**: Security and access management

## 📋 Prerequisites

Before deploying this infrastructure, ensure you have:

- **AWS CLI** configured with appropriate credentials
- **Terraform** (v1.0+) installed
- **Docker** installed and running
- **kubectl** installed for Kubernetes management
- **Node.js** (v18+) for local development
- **Git** for version control

### AWS Permissions Required

Your AWS user/role needs permissions for:
- EKS cluster management
- ECR repository operations
- S3 bucket operations
- Lambda function deployment
- SNS/SQS operations
- CloudWatch monitoring
- IAM role/policy management
- VPC and networking operations

## 🚀 Quick Start

### 1. Deploy Infrastructure

```bash

# Deploy the complete infrastructure
./1.deploy-infra.sh
```

This script will:
- Initialize Terraform
- Create all AWS resources
- Configure kubectl for the EKS cluster
- Display deployment outputs

### 2. Build and Deploy Application

```bash
# Build and push Docker image to ECR
./2.deploy-to-ecr.sh

# Deploy application to EKS cluster
./3.deploy.sh
```

### 3. Test the Pipeline

```bash
# Test the complete pipeline with a sample image
./4.test-pipeline.sh
```

### 4. Clean Up Resources

```bash
# Remove all AWS resources to avoid charges
./5.cleanup.sh
```