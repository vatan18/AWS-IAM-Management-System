# AWS IAM Management System

A comprehensive IAM user and group management system for AWS, designed for both standard operations and emergency scenarios.

## 🏗️ Architecture Overview

```
AWS IAM Management
├── 🟢 STANDARD OPERATIONS (Planned)
│   ├── Pre-defined groups with AWS managed policies
│   └── Structured user onboarding
└── 🚨 EMERGENCY OPERATIONS (Urgent)
    ├── Custom groups with custom policies
    └── Rapid user deployment
```

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Standard Operations](#standard-operations)
- [Emergency Operations](#emergency-operations)
- [Available Groups](#available-groups)
- [Scripts Overview](#scripts-overview)
- [Usage Examples](#usage-examples)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with admin permissions
- `jq` installed for JSON processing
- Bash shell environment

### Installation
```bash
# Clone or download the scripts
chmod +x *.sh
```

### Initial Setup (One-time)
```bash
# Setup standard IAM groups
./setup-iam-groups.sh --profile 81
```

## 🟢 STANDARD OPERATIONS

For planned, structured IAM management using pre-defined groups.

### Standard Groups Setup

| Group | Permissions | Use Case |
|-------|-------------|----------|
| **Developers** | Read-only + ECR/EKS access | Development team members |
| **S3-Readers** | S3 read-only access | Users needing S3 access only |
| **EKS-Deployers** | EKS cluster + ECR access | Kubernetes deployment team |
| **Read-Only-Users** | Read-only all services | Auditors, viewers |
| **Power-Users** | Power user access (no IAM) | Advanced users |
| **Admins** | Full administrator access | System administrators |

### Standard Scripts

#### 1. `setup-iam-groups.sh` - Initial Group Setup
```bash
# One-time setup of all standard groups
./setup-iam-groups.sh --profile 81
```

#### 2. `create-user-to-group.sh` - Standard User Creation
```bash
# Syntax: ./create-user-to-group.sh --profile PROFILE USERNAME GROUP

# Examples:
./create-user-to-group.sh --profile 81 alice-dev Developers
./create-user-to-group.sh --profile 81 bob-viewer S3-Readers
./create-user-to-group.sh --profile 81 carol-admin Admins
```

## 🚨 EMERGENCY OPERATIONS

For urgent, custom IAM requirements without script modifications.

### Emergency Scripts

#### 1. `create-emergency-group.sh` - Emergency Group Creation
```bash
# Syntax: 
# ./create-emergency-group.sh --profile PROFILE GROUP_NAME 'POLICY_JSON' "DESCRIPTION"

# Real-world examples:

# Logs Viewer Team
./create-emergency-group.sh --profile 81 Logs-Viewers '{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": ["logs:Describe*", "logs:Get*", "logs:List*"],
        "Resource": "*"
    }]
}' "Emergency CloudWatch Logs access"

# Cost Monitoring Team  
./create-emergency-group.sh --profile 81 Cost-Viewers '{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow", 
        "Action": ["ce:*", "budgets:ViewBudget"],
        "Resource": "*"
    }]
}' "Emergency cost monitoring access"
```

#### 2. `add-user-to-existing-group.sh` - Rapid User Addition
```bash
# Syntax: ./add-user-to-existing-group.sh --profile PROFILE USERNAME GROUP_NAME

# Examples:
./add-user-to-existing-group.sh --profile 81 emergency-user Logs-Viewers
./add-user-to-existing-group.sh --profile 81 finance-user Cost-Viewers
```

### Common Emergency Use Cases

#### 🆘 Incident Response Team
```bash
# 1. Create security auditors group
./create-emergency-group.sh --profile 81 Security-Auditors '{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": [
            "cloudtrail:LookupEvents",
            "guardduty:GetFindings", 
            "securityhub:GetFindings"
        ],
        "Resource": "*"
    }]
}' "Emergency security incident response"

# 2. Add incident responders
./add-user-to-existing-group.sh --profile 81 incident-responder1 Security-Auditors
./add-user-to-existing-group.sh --profile 81 incident-responder2 Security-Auditors
```

#### 🆘 Backup Restoration Team
```bash
# 1. Create backup admins group
./create-emergency-group.sh --profile 81 Backup-Admins '{
    "Version": "2012-10-17", 
    "Statement": [{
        "Effect": "Allow",
        "Action": ["backup:*", "ec2:DescribeInstances"],
        "Resource": "*"
    }]
}' "Emergency backup restoration team"

# 2. Add DR team members
./add-user-to-existing-group.sh --profile 81 dr-team1 Backup-Admins
```

## 📊 Available Groups Reference

### Standard Groups (After running setup-iam-groups.sh)

| Group | AWS Managed Policies | Custom Policies | Description |
|-------|---------------------|-----------------|-------------|
| **Developers** | `ReadOnlyAccess` | ECR push/pull, EKS describe | Development team with container access |
| **S3-Readers** | `AmazonS3ReadOnlyAccess` | - | S3 bucket viewers |
| **EKS-Deployers** | `AmazonEKSClusterPolicy` | - | Kubernetes deployment team |
| **Read-Only-Users** | `ReadOnlyAccess` | - | Read-only across all services |
| **Power-Users** | `PowerUserAccess` | - | Full access except IAM |
| **Admins** | `AdministratorAccess` | - | Full administrative access |

### Emergency Groups (Created as needed)

| Group | Typical Permissions | Use Case |
|-------|---------------------|----------|
| **Logs-Viewers** | CloudWatch Logs read | Support team debugging |
| **Cost-Viewers** | Cost Explorer, Budgets | Finance team monitoring |
| **Backup-Admins** | AWS Backup full access | Disaster recovery team |
| **Security-Auditors** | CloudTrail, GuardDuty | Security incident response |

## 🛠️ Scripts Overview

### Standard Operation Scripts

#### `setup-iam-groups.sh`
- **Purpose**: One-time setup of standard IAM groups
- **Usage**: `./setup-iam-groups.sh --profile PROFILE`
- **Creates**: 6 standard groups with AWS managed policies
- **Run Frequency**: Once per AWS account

#### `create-user-to-group.sh` 
- **Purpose**: Create users and assign to existing groups
- **Usage**: `./create-user-to-group.sh --profile PROFILE USERNAME GROUP`
- **Output**: User credentials in `~/.aws/keys/`
- **Run Frequency**: As needed for new users

### Emergency Operation Scripts

#### `create-emergency-group.sh`
- **Purpose**: Rapid creation of custom groups with custom policies
- **Usage**: `./create-emergency-group.sh --profile PROFILE GROUP 'POLICY_JSON' "DESC"`
- **Features**: 
  - No script modification needed
  - Creates group + custom policy in one command
  - Validates JSON policy syntax
- **Run Frequency**: Emergency situations only

#### `add-user-to-existing-group.sh`
- **Purpose**: Quickly add users to any existing group
- **Usage**: `./add-user-to-existing-group.sh --profile PROFILE USERNAME GROUP`
- **Features**:
  - Creates user if not exists
  - Generates access keys automatically
  - 30-second user deployment
- **Run Frequency**: Emergency user onboarding

## 📝 Usage Examples

### Standard Workflow (Planned)
```bash
# 1. Initial setup (one-time)
./setup-iam-groups.sh --profile 81

# 2. Create developers
./create-user-to-group.sh --profile 81 john-dev Developers
./create-user-to-group.sh --profile 81 jane-dev Developers

# 3. Create S3 viewers  
./create-user-to-group.sh --profile 81 bob-viewer S3-Readers
```

### Emergency Workflow (Urgent)
```bash
# 1. Create emergency group with custom policy (2 minutes)
./create-emergency-group.sh --profile 81 Logs-Viewers '{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": ["logs:Describe*", "logs:Get*"],
        "Resource": "*"
    }]
}' "Emergency logs access"

# 2. Add emergency users (30 seconds each)
./add-user-to-existing-group.sh --profile 81 support1 Logs-Viewers
./add-user-to-existing-group.sh --profile 81 support2 Logs-Viewers
```

### One-Liner Emergency Deployment
```bash
# Complete emergency setup in one command
./create-emergency-group.sh --profile 81 Emergency-Group '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["service:Permission"],"Resource":"*"}]}' "Emergency access" && ./add-user-to-existing-group.sh --profile 81 emergency-user Emergency-Group
```

## 🔒 Security Best Practices

### Access Management
- ✅ Use groups for permission management
- ✅ Follow principle of least privilege
- ✅ Regular access reviews (quarterly)
- ✅ Enable MFA for all users
- ✅ Rotate access keys every 90 days

### Emergency Procedures
- 🚨 Document emergency group purposes
- 🚨 Time-bound emergency access
- 🚨 Review and remove emergency access post-incident
- 🚨 Audit emergency group usage

### Credential Security
- 🔐 Access keys stored in `~/.aws/keys/` with 600 permissions
- 🔐 Never commit credentials to version control
- 🔐 Use IAM roles when possible instead of access keys

## 🗂️ File Structure
```
.
├── 📄 README.md                          # This file
├── 🟢 setup-iam-groups.sh               # Standard group setup
├── 🟢 create-user-to-group.sh           # Standard user creation
├── 🚨 create-emergency-group.sh         # Emergency group creation  
├── 🚨 add-user-to-existing-group.sh     # Emergency user addition
└── 📁 ~/.aws/keys/                      # Auto-created key storage
    └── user_account_accessKeys.csv
```

## 🔍 Management & Monitoring

### List All Groups
```bash
aws iam list-groups --profile 81 --query 'Groups[].GroupName'
```

### Check Group Members
```bash
aws iam get-group --group-name Developers --profile 81
```

### Verify User Permissions
```bash
# After creating user, test their access
export AWS_ACCESS_KEY_ID="ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SECRET_KEY"
aws sts get-caller-identity
aws s3 ls        # For S3-Readers
aws logs describe-log-groups  # For Logs-Viewers
```

### Audit Group Policies
```bash
# See attached policies for any group
aws iam list-attached-group-policies --group-name GROUP_NAME --profile 81
```

## 🚨 Troubleshooting

### Common Issues

#### "AWS CLI not configured"
```bash
# Set up AWS CLI first
aws configure --profile 81
# or set environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..." 
export AWS_DEFAULT_REGION="us-east-1"
```

#### "jq command not found"
```bash
# Install jq
sudo apt-get install jq        # Ubuntu/Debian
brew install jq               # macOS
yum install jq                # CentOS/RHEL
```

#### "User already exists"
- Script will detect and skip user creation
- New access keys will be generated

#### "Policy validation failed"
- Check JSON syntax in policy document
- Use online JSON validators if needed
- Ensure proper escaping in command line

### Debug Mode
```bash
# Add debug output to any script
bash -x ./create-emergency-group.sh --profile 81 Test-Group '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:ListBuckets"],"Resource":"*"}]}' "Test"
```

## 📞 Support

### Standard Operations
- Use `setup-iam-groups.sh` and `create-user-to-group.sh`
- Follow predefined group structure
- Plan user onboarding in advance

### Emergency Operations  
- Use `create-emergency-group.sh` and `add-user-to-existing-group.sh`
- No script modifications needed
- Document emergency access purposes
- Clean up after emergency resolved

### Getting Help
1. Check script usage: `./script-name.sh --help`
2. Verify AWS CLI: `aws sts get-caller-identity --profile 81`
3. Check group exists: `aws iam list-groups --profile 81`

---

**Remember**: Use standard scripts for planned operations and emergency scripts for urgent requirements. No script modifications are needed for custom scenarios!