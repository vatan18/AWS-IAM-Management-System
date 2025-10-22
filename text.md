## 📋 IAM Usage Examples

### 1. Setup All Standard Groups (One-time)
```bash
./setup-iam-groups.sh --profile 81
```

### 2. Create Users for Different Roles
```bash
# Development team
./create-user.sh --profile 81 --username john.dev --group Developers
./create-user.sh --profile 81 --username alice.senior --group Senior-Developers

# Infrastructure team
./create-user.sh --profile 81 --username bob.network --group Network-Admins
./create-user.sh --profile 81 --username carol.eks --group EKS-Admins

# Security team
./create-user.sh --profile 81 --username dave.security --group Security-Admins
./create-user.sh --profile 81 --username eve.audit --group Security-Auditors

# Database team
./create-user.sh --profile 81 --username frank.db --group Database-Admins
./create-user.sh --profile 81 --username grace.s3 --group S3-Admins
```

### 3. Create Custom Groups (If needed)
```bash
# Using AWS managed policy
./create-group.sh --profile 81 --group-name Custom-Monitoring --policy CloudWatchReadOnlyAccess

# Using Custom Policy (Inline JSON)
./create-group.sh --profile 81 --group-name Special-Access --custom-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:*"],"Resource":"arn:aws:s3:::special-bucket/*"}]}'

# Using Custom Policy (From File)
# Create policy file
cat > my-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::my-bucket",
                "arn:aws:s3:::my-bucket/*"
            ]
        }
    ]
}
EOF
# Use the policy file
./create-group.sh --profile 81 --group-name Special-Access --custom-policy-file my-policy.json --description "Special S3 access"
# More Complex Policy File Example:
# Create a comprehensive policy file
cat > ecr-eks-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECRAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EKSReadAccess",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters",
                "eks:ListFargateProfiles",
                "eks:ListNodegroups"
            ],
            "Resource": "*"
        }
    ]
}
EOF

./create-group.sh --profile 81 --group-name ECR-EKS-Access --custom-policy-file ecr-eks-policy.json --description "Container developers"
```

## 👥 Comprehensive Groups Available

### 🏢 ADMINISTRATION & ACCESS
| Group | Policy | Purpose |
|-------|---------|---------|
| **Super-Admins** | `AdministratorAccess` | Full AWS account access |
| **Billing-Admins** | `AWSBillingReadOnlyAccess` | Cost and billing management |
| **IAM-Admins** | `IAMFullAccess` | User and access management |

### 💻 DEVELOPMENT & CI/CD
| Group | Policy | Purpose |
|-------|---------|---------|
| **Developers** | `ReadOnlyAccess` | Junior developers, read-only |
| **Senior-Developers** | `PowerUserAccess` | Senior developers, full access except IAM |
| **CI-CD-Engineers** | `AWSCodePipeline_FullAccess` | CI/CD pipeline management |
| **Container-Engineers** | `AmazonEC2ContainerRegistryPowerUser` | ECR and container management |
| **Lambda-Developers** | `AWSLambda_FullAccess` | Serverless development |

### 🏗️ INFRASTRUCTURE & OPERATIONS
| Group | Policy | Purpose |
|-------|---------|---------|
| **Network-Admins** | `AmazonVPCFullAccess` | VPC, subnets, networking |
| **EC2-Admins** | `AmazonEC2FullAccess` | EC2 instance management |
| **EKS-Admins** | `AmazonEKSClusterPolicy` | Kubernetes cluster management |
| **EKS-Developers** | `AmazonEKSWorkerNodePolicy` | Kubernetes application deployment |
| **LoadBalancer-Admins** | `ElasticLoadBalancingFullAccess` | Load balancer management |
| **AutoScaling-Admins** | `AutoScalingFullAccess` | Auto scaling group management |

### 🔒 SECURITY & COMPLIANCE
| Group | Policy | Purpose |
|-------|---------|---------|
| **Security-Admins** | `SecurityAudit` | Security monitoring and auditing |
| **Security-Auditors** | `AWSConfigUserAccess` | Configuration and compliance auditing |
| **Compliance-Auditors** | `AWSSecurityHubReadOnlyAccess` | Security compliance monitoring |
| **KMS-Admins** | `AWSKeyManagementServicePowerUser` | Encryption key management |

### 💾 DATABASE & STORAGE
| Group | Policy | Purpose |
|-------|---------|---------|
| **Database-Admins** | `AmazonRDSFullAccess` | RDS database management |
| **DynamoDB-Admins** | `AmazonDynamoDBFullAccess` | DynamoDB management |
| **S3-Admins** | `AmazonS3FullAccess` | S3 bucket and object management |
| **EFS-Admins** | `AmazonElasticFileSystemFullAccess` | EFS file system management |

### 📊 MONITORING & SUPPORT
| Group | Policy | Purpose |
|-------|---------|---------|
| **Monitoring-Admins** | `CloudWatchFullAccess` | Monitoring and alerts management |
| **Logs-Viewers** | `CloudWatchLogsReadOnlyAccess` | Log analysis and troubleshooting |
| **Support-Engineers** | `AWSSupportAccess` | AWS support case management |
| **Cost-Optimizers** | `AWSCostExplorerReadOnlyAccess` | Cost analysis and optimization |

### 🎯 SPECIALIZED ROLES
| Group | Policy | Purpose |
|-------|---------|---------|
| **Data-Engineers** | `AmazonS3FullAccess` | Data processing and analytics |
| **ML-Engineers** | `AmazonSageMakerFullAccess` | Machine learning workflows |
| **Backup-Admins** | `AWSBackupFullAccess` | Backup and restore operations |
| **Disaster-Recovery** | `AWSBackupFullAccess` | DR planning and execution |

## 🛠️ Scripts Overview

- `setup-iam-groups.sh` - Creates 25+ standard groups for all DevOps needs
- `create-user.sh` - Creates users and assigns to any group
- `create-group.sh` - Creates additional custom groups if needed

## 💡 Typical Team Assignments

**Development Team:**
- Junior Developers → `Developers`
- Senior Developers → `Senior-Developers` 
- DevOps Engineers → `CI-CD-Engineers`, `Container-Engineers`

**Infrastructure Team:**
- Network Engineers → `Network-Admins`
- System Administrators → `EC2-Admins`, `AutoScaling-Admins`
- Kubernetes Team → `EKS-Admins`, `EKS-Developers`

**Security Team:**
- Security Engineers → `Security-Admins`
- Compliance Team → `Security-Auditors`, `Compliance-Auditors`

**Database Team:**
- DBAs → `Database-Admins`, `DynamoDB-Admins`
- Storage Admins → `S3-Admins`, `EFS-Admins`

## 🔒 Security Best Practices

- Access keys saved to `~/.aws/keys/`
- Principle of least privilege enforced
- Regular access reviews recommended
- MFA strongly encouraged for all users

*Note: Create additional groups using `create-group.sh` for any special requirements*

## 📋 Usage Examples for SSO

### 1. Create SSO Permission Sets

**Using AWS Managed Policy:**
```bash
./create-sso-group.sh --profile management-account --permission-set Developers --policy ReadOnlyAccess --description "Developers read-only access" --session-duration PT12H

./create-sso-group.sh --profile management-account --permission-set Admins --policy AdministratorAccess --description "Full admin access" --session-duration PT4H
```

**Using Custom Policy (Inline):**
```bash
./create-sso-group.sh --profile management-account --permission-set Logs-Viewers --custom-policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:Describe*",
                "logs:Get*", 
                "logs:List*",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}' --description "CloudWatch Logs access" --session-duration PT8H
```

**Using Custom Policy (File):**
```bash
# Create policy file
cat > ecr-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECRAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF

./create-sso-group.sh --profile management-account --permission-set Container-Devs --custom-policy-file ecr-policy.json --description "ECR access for container developers" --session-duration PT8H
```

### 2. Assign Users/Groups to Accounts

**Using Permission Set Name:**
```bash
# Assign user to development account
./assign-sso-user.sh --profile management-account --permission-set Developers --principal-type USER --principal-id a1b2c3d4-5678-90ab-cdef-123456789012 --account-id 123456789012

# Assign group to production account
./assign-sso-user.sh --profile management-account --permission-set Admins --principal-type GROUP --principal-id g1h2i3j4-5678-90ab-cdef-123456789012 --account-id 111222333444
```

**Using Permission Set ARN:**
```bash
./assign-sso-user.sh --profile management-account --permission-set-arn arn:aws:sso:::permissionSet/ssoins-123456/ps-789012 --principal-type USER --principal-id u1v2w3x4-5678-90ab-cdef-123456789012 --account-id 123456789012
```

### 3. Bulk Assignment Example

```bash
# Assign same user to multiple accounts
./assign-sso-user.sh --profile management-account --permission-set Developers --principal-type USER --principal-id u1v2w3x4-5678-90ab-cdef-123456789012 --account-id 111222333444
./assign-sso-user.sh --profile management-account --permission-set Developers --principal-type USER --principal-id u1v2w3x4-5678-90ab-cdef-123456789012 --account-id 555666777888
./assign-sso-user.sh --profile management-account --permission-set Developers --principal-type USER --principal-id u1v2w3x4-5678-90ab-cdef-123456789012 --account-id 999000111222
```

## 🔧 Helper Scripts

### List SSO Permission Sets (`list-sso-permission-sets.sh`)


Here are comprehensive IAM Roles scripts covering all real-world use cases:

## 🛠️ IAM Roles

## 📋 Real-World Use Cases & Examples

### 1. EC2 Instance Roles

**Web Server with S3 Access:**
```bash
./create-role.sh --profile 81 --role-name WebServer-Role --type ec2 --policy AmazonS3ReadOnlyAccess --description "Web server role for S3 static content"

# Launch EC2 with the role
aws ec2 run-instances --image-id ami-0c02fb55956c7d316 --instance-type t3.micro --iam-instance-profile Name=WebServer-Role --profile 81
```

**Application Server with Multiple Services:**
```bash
# Create custom policy file
cat > app-server-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Query",
                "sqs:SendMessage",
                "sqs:ReceiveMessage"
            ],
            "Resource": "*"
        }
    ]
}
EOF

./create-role.sh --profile 81 --role-name AppServer-Role --type ec2 --custom-policy-file app-server-policy.json --description "Application server role"
```

### 2. Lambda Function Roles

**Basic Lambda with CloudWatch Logs:**
```bash
./create-role.sh --profile 81 --role-name MyLambda-Role --type lambda --policy AWSLambdaBasicExecutionRole --description "Lambda function role"
```

**Lambda with S3 and DynamoDB Access:**
```bash
./create-role.sh --profile 81 --role-name DataProcessor-Role --type lambda --custom-policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:*",
                "s3:GetObject",
                "s3:PutObject",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "*"
        }
    ]
}' --description "Data processing Lambda role"
```

### 3. Cross-Account Roles

**Development Account Access:**
```bash
./create-role.sh --profile production-account --role-name CrossAccount-Dev --type cross-account --trust-account 123456789012 --policy ReadOnlyAccess --description "Cross-account access for developers"
```

**Production Access with External ID:**
```bash
./create-role.sh --profile production-account --role-name CrossAccount-CI-CD --type cross-account --trust-account 111222333444 --external-id cicd-2024 --policy AdministratorAccess --description "CI/CD deployment access"
```

**Custom Cross-Account Policy:**
```bash
cat > cross-account-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "s3:ListBucket",
                "s3:GetObject",
                "cloudwatch:GetMetricStatistics",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF

./create-role.sh --profile 81 --role-name Monitoring-Role --type cross-account --trust-account 333444555666 --custom-policy-file cross-account-policy.json --description "Cross-account monitoring role"
```

### 4. Service-Linked Roles

**ECS Service Role:**
```bash
./create-role.sh --profile 81 --role-name MyECS-Role --type service-linked --service-name ecs.amazonaws.com --description "ECS service-linked role"
```

**ELB Service Role:**
```bash
./create-role.sh --profile 81 --role-name MyELB-Role --type service-linked --service-name elasticloadbalancing.amazonaws.com --description "ELB service-linked role"
```

**Custom Suffix Service Role:**
```bash
./create-role.sh --profile 81 --role-name MyApp-RDS-Role --type service-linked --service-name rds.amazonaws.com --custom-suffix MyApplication --description "RDS service role for MyApplication"
```

### 5. Custom Trust Roles

**Role for Specific AWS Service:**
```bash
./create-role.sh --profile 81 --role-name APIGateway-Role --type custom --trust-policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "apigateway.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}' --policy AmazonS3FullAccess --description "API Gateway role for S3 integration"
```

**Role with Multiple Trusted Entities:**
```bash
cat > multi-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::123456789012:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

./create-role.sh --profile 81 --role-name MultiTrust-Role --type custom --trust-policy-file multi-trust-policy.json --policy ReadOnlyAccess --description "Role trusted by Lambda and cross-account"
```

## 🔄 Using Assume Role

**Basic Role Assumption:**
```bash
./assume-role.sh --profile 81 --role-arn arn:aws:iam::123456789012:role/CrossAccount-Dev --export

# Test the assumed role
export AWS_ACCESS_KEY_ID="..." AWS_SECRET_ACCESS_KEY="..." AWS_SESSION_TOKEN="..."
aws sts get-caller-identity
aws s3 ls
```

**With External ID:**
```bash
./assume-role.sh --profile 81 --role-arn arn:aws:iam::123456789012:role/CrossAccount-Prod --external-id prod2024 --duration 7200 --export
```

**JSON Output:**
```bash
./assume-role.sh --profile 81 --role-arn arn:aws:iam::123456789012:role/ReadOnly-Role --output json
```

**Credentials File Output:**
```bash
./assume-role.sh --profile 81 --role-arn arn:aws:iam::123456789012:role/Dev-Role --output credentials >> ~/.aws/credentials
```

## 🎯 Real-World Scenarios

### Scenario 1: CI/CD Pipeline
```bash
# Create cross-account role for deployment
./create-role.sh --profile production-account --role-name CI-CD-Deploy --type cross-account --trust-account 111222333444 --external-id cicd-pipeline --policy AdministratorAccess --description "CI/CD deployment role"

# In CI/CD pipeline, assume the role
./assume-role.sh --profile ci-account --role-arn arn:aws:iam::123456789012:role/CI-CD-Deploy --external-id cicd-pipeline --export
```

### Scenario 2: Multi-Service Application
```bash
# Create EC2 role for web tier
./create-role.sh --profile 81 --role-name WebTier-Role --type ec2 --custom-policy-file web-tier-policy.json

# Create Lambda role for processing
./create-role.sh --profile 81 --role-name Processor-Role --type lambda --custom-policy-file processor-policy.json

# Create cross-account role for shared services
./create-role.sh --profile 81 --role-name SharedServices-Role --type cross-account --trust-account 999888777666 --policy AmazonS3ReadOnlyAccess
```

### Scenario 3: Security Auditing
```bash
# Create cross-account read-only role for auditors
./create-role.sh --profile app-account --role-name Security-Audit --type cross-account --trust-account 333444555666 --policy SecurityAudit --description "Security audit role"

# Auditors assume the role
./assume-role.sh --profile audit-account --role-arn arn:aws:iam::123456789012:role/Security-Audit --role-session-name SecurityAudit --duration 10800 --export
```

These scripts cover every possible IAM role scenario with real-world examples and support for both inline policies and policy files!