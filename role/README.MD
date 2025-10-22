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

## 🛠️ Scripts Details

### `create-role.sh`
**Purpose**: Creates various types of IAM roles with flexible trust and access policies

**Role Types:**
- `ec2` - EC2 instance roles (creates instance profile automatically)
- `lambda` - Lambda function execution roles
- `cross-account` - Roles for cross-account access
- `service-linked` - AWS service-linked roles
- `custom` - Roles with custom trust policies

**Policy Options:**
- `--policy POLICY_NAME` - Use AWS managed policy
- `--custom-policy 'JSON'` - Use inline JSON policy
- `--custom-policy-file FILE` - Use policy from JSON file

### `assume-role.sh`
**Purpose**: Assumes IAM roles for temporary access with multiple output formats

**Output Formats:**
- `env` - Environment variable format (default)
- `json` - Raw JSON output
- `credentials` - AWS credentials file format

**Features:**
- Configurable session duration (up to 12 hours)
- External ID support for cross-account roles
- Export to environment variables
- Multiple output formats

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

## 🔧 Common Service-Linked Roles

| Service | Service Name | Use Case |
|---------|--------------|----------|
| **ECS** | `ecs.amazonaws.com` | Container management |
| **ELB** | `elasticloadbalancing.amazonaws.com` | Load balancing |
| **RDS** | `rds.amazonaws.com` | Database management |
| **EKS** | `eks.amazonaws.com` | Kubernetes service |
| **Lambda** | `lambda.amazonaws.com` | Serverless computing |
| **OpsWorks** | `opsworks.amazonaws.com` | Configuration management |

## 🔒 Security Best Practices

### Trust Policy Security
- Use conditions in trust policies for additional security
- Limit trusted entities to specific accounts or services
- Use external IDs for cross-account roles

### Access Policy Security
- Follow principle of least privilege
- Use conditions to restrict access
- Regular policy reviews and audits

### Session Management
- Set appropriate session durations
- Use role chaining carefully
- Monitor role usage with CloudTrail

## 🚨 Troubleshooting

### Common Issues
- **"Cannot assume role"**: Check trust policy and permissions
- **"External ID mismatch"**: Verify external ID in both role creation and assumption
- **"Session duration too long"**: Maximum is 12 hours (43200 seconds)
- **"Role not found"**: Verify role name and account ID

### Verification Commands
```bash
# Check role details
aws iam get-role --role-name MyRole --profile 81

# Check role policies
aws iam list-attached-role-policies --role-name MyRole --profile 81
aws iam list-role-policies --role-name MyRole --profile 81

# Test role assumption
./assume-role.sh --profile 81 --role-arn arn:aws:iam::123456789012:role/MyRole --output json
```

### Debugging Trust Relationships
```bash
# Check trust policy
aws iam get-role --role-name MyRole --query Role.AssumeRolePolicyDocument --profile 81 --output json

# Simulate policy evaluation
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::123456789012:user/MyUser \
    --action-names s3:ListBuckets ec2:DescribeInstances \
    --profile 81
```

## 📊 Monitoring & Compliance

### CloudTrail Events
- `AssumeRole` - Role assumption events
- `AssumeRoleWithWebIdentity` - Web identity federation
- `AssumeRoleWithSAML` - SAML federation

### Best Practices
- Enable CloudTrail logging
- Monitor role usage patterns
- Regular access reviews
- Use service control policies (SCPs) in Organizations

*Note: Service-linked roles are managed by AWS and have specific use cases. Customize them only when necessary.*
```
