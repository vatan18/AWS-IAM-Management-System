## 📋 Usage Examples

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