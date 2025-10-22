## 📋 Usage Examples

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

## 🛠️ Scripts Details

### `create-sso-group.sh`
**Purpose**: Creates SSO permission sets with AWS managed policies or custom policies
**Usage Options**:
- `--policy POLICY_NAME` - Use AWS managed policy
- `--custom-policy 'JSON'` - Use inline JSON policy  
- `--custom-policy-file FILE` - Use policy from JSON file

**Additional Parameters**:
- `--session-duration DURATION` - Session duration (PT1H, PT4H, PT8H, PT12H)
- `--region REGION` - AWS region (default: us-east-1)

### `assign-sso-user.sh`
**Purpose**: Assigns users or groups to AWS accounts with specific permission sets
**Usage Options**:
- `--permission-set NAME` - Use permission set name
- `--permission-set-arn ARN` - Use permission set ARN directly

**Parameters**:
- `--principal-type TYPE` - USER or GROUP
- `--principal-id ID` - User/Group ID from Identity Store
- `--account-id ID` - Target AWS account ID

### `list-sso-permission-sets.sh`
**Purpose**: Lists all available SSO permission sets
**Usage**: `./list-sso-permission-sets.sh --profile management-account`

## 🏗️ SSO Architecture

```
AWS Organizations
├── Management Account
│   └── AWS SSO
│       ├── Permission Sets
│       └── Identity Source
└── Member Accounts
    └── SSO Assignments
```

## 💡 Common Permission Sets

### Standard Permission Sets
| Permission Set | Policy | Session | Use Case |
|----------------|---------|---------|----------|
| **Developers** | `ReadOnlyAccess` | PT12H | Development team access |
| **Admins** | `AdministratorAccess` | PT4H | Full administrative access |
| **Security** | `SecurityAudit` | PT8H | Security monitoring |
| **Billing** | `AWSBillingReadOnlyAccess` | PT12H | Cost management |
| **Support** | `AWSSupportAccess` | PT8H | AWS support access |

### Custom Permission Sets Examples

**Database Administrators:**
```bash
./create-sso-group.sh --profile management-account --permission-set DB-Admins --custom-policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "dynamodb:*",
                "redshift:*"
            ],
            "Resource": "*"
        }
    ]
}' --session-duration PT8H
```

**Network Engineers:**
```bash
./create-sso-group.sh --profile management-account --permission-set Network-Engineers --custom-policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVpc",
                "ec2:DeleteVpc",
                "ec2:ModifyVpcAttribute",
                "ec2:DescribeVpcs",
                "ec2:CreateSubnet",
                "ec2:DeleteSubnet",
                "ec2:DescribeSubnets"
            ],
            "Resource": "*"
        }
    ]
}' --session-duration PT8H
```

## 🎯 Real-World Scenarios

### Scenario 1: Development Team Across Multiple Accounts
```bash
# Create permission set
./create-sso-group.sh --profile management-account --permission-set Dev-ReadOnly --policy ReadOnlyAccess --session-duration PT12H

# Assign to development accounts
./assign-sso-user.sh --profile management-account --permission-set Dev-ReadOnly --principal-type GROUP --principal-id dev-group-id --account-id 111222333444
./assign-sso-user.sh --profile management-account --permission-set Dev-ReadOnly --principal-type GROUP --principal-id dev-group-id --account-id 555666777888
```

### Scenario 2: Production Access with Limited Sessions
```bash
# Short session for production access
./create-sso-group.sh --profile management-account --permission-set Prod-Admins --policy AdministratorAccess --session-duration PT4H

# Assign to production account only
./assign-sso-user.sh --profile management-account --permission-set Prod-Admins --principal-type USER --principal-id admin-user-id --account-id 999000111222
```

### Scenario 3: Cross-Functional Teams
```bash
# Create specialized permission sets
./create-sso-group.sh --profile management-account --permission-set Data-Engineers --custom-policy-file data-policy.json
./create-sso-group.sh --profile management-account --permission-set ML-Engineers --policy AmazonSageMakerFullAccess

# Assign to appropriate accounts
./assign-sso-user.sh --profile management-account --permission-set Data-Engineers --principal-type GROUP --principal-id data-team-id --account-id 111222333444
./assign-sso-user.sh --profile management-account --permission-set ML-Engineers --principal-type GROUP --principal-id ml-team-id --account-id 555666777888
```

## 🔧 Helper Commands

### Get User/Group IDs from Identity Store
```bash
# List users (requires AWS SSO Identity Store API)
aws identitystore list-users --identity-store-id d-1234567890 --region us-east-1 --profile management-account

# List groups
aws identitystore list-groups --identity-store-id d-1234567890 --region us-east-1 --profile management-account
```

### Check Account Assignments
```bash
# List assignments for an account
aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-123456 \
    --account-id 123456789012 \
    --region us-east-1 \
    --profile management-account
```

### List Permission Sets
```bash
./list-sso-permission-sets.sh --profile management-account
```

## 🔒 Security Best Practices

- **Session Duration**: Set appropriate session durations based on role sensitivity
- **MFA Enforcement**: Enable MFA in SSO settings
- **Conditional Access**: Use conditions in permission set policies
- **Regular Reviews**: Review and clean up unused assignments
- **Least Privilege**: Grant minimum required permissions

## 🚨 Troubleshooting

### Common Issues
- **"No SSO instance found"**: Ensure AWS SSO is enabled in the management account
- **"Permission set not found"**: Check permission set name spelling and region
- **"Principal not found"**: Verify user/group ID from Identity Store
- **Assignment not appearing**: Allow few minutes for provisioning

### Verification Steps
```bash
# Check SSO instance
aws sso-admin list-instances --region us-east-1 --profile management-account

# List permission sets
aws sso-admin list-permission-sets --instance-arn arn:aws:sso:::instance/ssoins-123456 --region us-east-1 --profile management-account

# Test SSO login
aws sso login --profile sso-profile-name
```