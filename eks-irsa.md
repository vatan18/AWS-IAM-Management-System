## 1. IRSA (IAM Roles for Service Accounts) - Primary Method

### Complete IRSA Setup Template:

```yaml
# eks-irsa-setup.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'EKS IAM Roles for Service Accounts (IRSA) Setup'

Parameters:
  Environment:
    Type: String
    Default: dev
  AppName:
    Type: String
  EKSClusterName:
    Type: String
  OIDCProviderUrl:
    Type: String
    Description: EKS OIDC Provider URL (without https://)

Resources:
  # IAM Role for Service Account
  MyAppServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-irsa-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub arn:aws:iam::${AWS::AccountId}:oidc-provider/${OIDCProviderUrl}
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderUrl}:aud: sts.amazonaws.com
                !Sub ${OIDCProviderUrl}:sub: system:serviceaccount:default:my-app-serviceaccount
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # S3 Access Policy for IRSA
  S3AccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-s3-irsa-${Environment}
      Roles:
        - !Ref MyAppServiceAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:GetObject
              - s3:PutObject
              - s3:DeleteObject
              - s3:ListBucket
            Resource:
              - !Sub arn:aws:s3:::${AppName}-data-${Environment}
              - !Sub arn:aws:s3:::${AppName}-data-${Environment}/*

  # DynamoDB Policy for IRSA
  DynamoDBAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-dynamodb-irsa-${Environment}
      Roles:
        - !Ref MyAppServiceAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - dynamodb:GetItem
              - dynamodb:PutItem
              - dynamodb:UpdateItem
              - dynamodb:DeleteItem
              - dynamodb:Query
              - dynamodb:Scan
              - dynamodb:BatchGetItem
            Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${AppName}-${Environment}-*

  # Secrets Manager Policy
  SecretsAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-secrets-irsa-${Environment}
      Roles:
        - !Ref MyAppServiceAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - secretsmanager:GetSecretValue
              - secretsmanager:DescribeSecret
            Resource: !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${AppName}/${Environment}/*

Outputs:
  ServiceAccountRoleArn:
    Description: IAM Role ARN for Service Account
    Value: !GetAtt MyAppServiceAccountRole.Arn
    Export:
      Name: !Sub ${AppName}-IRSA-Role-${Environment}
```

### Kubernetes Service Account Manifest:

```yaml
# kubernetes/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-serviceaccount
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MyApp-irsa-dev
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: my-app-serviceaccount  # This is crucial!
      containers:
      - name: my-app
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
        env:
        - name: AWS_REGION
          value: us-east-1
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

## 2. Multiple Service Accounts for Different Microservices

```yaml
# eks-multiple-irsa.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Multiple IRSA roles for different microservices'

Parameters:
  Environment:
    Type: String
    Default: dev
  AppName:
    Type: String
  OIDCProviderUrl:
    Type: String

Resources:
  # API Service Account Role
  ApiServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-api-irsa-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub arn:aws:iam::${AWS::AccountId}:oidc-provider/${OIDCProviderUrl}
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderUrl}:sub: system:serviceaccount:default:api-serviceaccount
      Path: /

  # Worker Service Account Role
  WorkerServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-worker-irsa-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub arn:aws:iam::${AWS::AccountId}:oidc-provider/${OIDCProviderUrl}
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderUrl}:sub: system:serviceaccount:default:worker-serviceaccount
      Path: /

  # API Service Policies
  ApiDynamoDBPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-api-dynamodb-${Environment}
      Roles: [!Ref ApiServiceAccountRole]
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - dynamodb:GetItem
              - dynamodb:PutItem
              - dynamodb:UpdateItem
              - dynamodb:Query
            Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${AppName}-api-${Environment}

  # Worker Service Policies
  WorkerS3Policy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-worker-s3-${Environment}
      Roles: [!Ref WorkerServiceAccountRole]
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:GetObject
              - s3:PutObject
              - s3:DeleteObject
            Resource: !Sub arn:aws:s3:::${AppName}-processing-${Environment}/*
```

### Multiple Kubernetes Service Accounts:

```yaml
# kubernetes/multiple-service-accounts.yaml
---
# API Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-serviceaccount
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MyApp-api-irsa-dev

---
# API Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  template:
    spec:
      serviceAccountName: api-serviceaccount
      containers:
      - name: api
        image: api:latest

---
# Worker Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: worker-serviceaccount
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MyApp-worker-irsa-dev

---
# Worker Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker-deployment
spec:
  template:
    spec:
      serviceAccountName: worker-serviceaccount
      containers:
      - name: worker
        image: worker:latest
```

## 3. Namespace-Specific Service Accounts

```yaml
# eks-namespaced-irsa.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Namespace-specific IRSA roles'

Parameters:
  Environment:
    Type: String
  AppName:
    Type: String
  OIDCProviderUrl:
    Type: String

Resources:
  # Frontend Namespace Role
  FrontendServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-frontend-irsa-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub arn:aws:iam::${AWS::AccountId}:oidc-provider/${OIDCProviderUrl}
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderUrl}:sub: system:serviceaccount:frontend:frontend-serviceaccount
      Path: /

  # Backend Namespace Role
  BackendServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-backend-irsa-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub arn:aws:iam::${AWS::AccountId}:oidc-provider/${OIDCProviderUrl}
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderUrl}:sub: system:serviceaccount:backend:backend-serviceaccount
      Path: /
```

## 4. Automated IRSA Setup Script

```bash
#!/bin/bash
# setup-eks-irsa.sh

set -euo pipefail

CLUSTER_NAME="my-eks-cluster"
ENVIRONMENT="dev"
APP_NAME="myapp"
REGION="us-east-1"

# Get OIDC Provider URL
get_oidc_provider() {
    local cluster_name=$1
    local oidc_issuer=$(aws eks describe-cluster \
        --name $cluster_name \
        --query "cluster.identity.oidc.issuer" \
        --output text | sed 's|https://||')
    
    echo $oidc_issuer
}

# Create IAM OIDC Provider
setup_oidc_provider() {
    local cluster_name=$1
    local oidc_url=$(get_oidc_provider $cluster_name)
    
    # Check if OIDC provider already exists
    if ! aws iam list-open-id-connect-providers | grep -q $oidc_url; then
        echo "Creating OIDC Provider for cluster..."
        aws eks associate-identity-provider-config \
            --cluster-name $cluster_name \
            --oidc identityProviderConfigName=default,issuerUrl=https://$oidc_url
    else
        echo "OIDC Provider already exists"
    fi
}

# Deploy IRSA Stack
deploy_irsa_stack() {
    local oidc_url=$(get_oidc_provider $CLUSTER_NAME)
    
    aws cloudformation deploy \
        --template-file eks-irsa-setup.yaml \
        --stack-name ${APP_NAME}-irsa-${ENVIRONMENT} \
        --parameter-overrides \
            Environment=$ENVIRONMENT \
            AppName=$APP_NAME \
            OIDCProviderUrl=$oidc_url \
        --capabilities CAPABILITY_NAMED_IAM
}

# Create Kubernetes Service Accounts
create_service_accounts() {
    local role_arn=$(aws cloudformation describe-stacks \
        --stack-name ${APP_NAME}-irsa-${ENVIRONMENT} \
        --query "Stacks[0].Outputs[?OutputKey=='ServiceAccountRoleArn'].OutputValue" \
        --output text)
    
    # Create service account manifest
    cat > service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${APP_NAME}-serviceaccount
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${role_arn}
EOF
    
    kubectl apply -f service-account.yaml
    
    # Update deployments to use the service account
    kubectl patch deployment ${APP_NAME}-deployment -p \
        '{"spec": {"template": {"spec": {"serviceAccountName": "'${APP_NAME}-serviceaccount'"}}}}'
}

# Verify IRSA Setup
verify_irsa() {
    echo "=== Verifying IRSA Setup ==="
    
    # Check service account
    kubectl get serviceaccount ${APP_NAME}-serviceaccount -o yaml
    
    # Check if pods can assume the role
    local test_pod=$(kubectl get pods -l app=${APP_NAME} -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$test_pod" ]; then
        echo "Testing AWS credentials in pod..."
        kubectl exec $test_pod -- aws sts get-caller-identity
    fi
}

main() {
    echo "Setting up IRSA for EKS cluster: $CLUSTER_NAME"
    
    setup_oidc_provider $CLUSTER_NAME
    deploy_irsa_stack
    create_service_accounts
    verify_irsa
    
    echo "IRSA setup completed successfully!"
}

main "$@"
```

## 5. Alternative: EKS Node Group Role (Less Secure)

**Note**: This is not recommended for production but included for completeness:

```yaml
# eks-node-role.yaml (Alternative - Not Recommended)
Resources:
  EKSNodeGroupRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
        - arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess
```

**Why Node Group Role is less secure:**
- All pods on the node share the same permissions
- No fine-grained access control
- Violates principle of least privilege
- Hard to audit which pod used which permission

## 6. Complete EKS IRSA Deployment

```bash
# Step-by-step deployment
./setup-eks-irsa.sh

# Apply Kubernetes manifests
kubectl apply -f kubernetes/service-account.yaml
kubectl apply -f kubernetes/deployment.yaml

# Verify
kubectl get pods -l app=my-app
kubectl exec <pod-name> -- aws sts get-caller-identity
```

## Key Benefits of IRSA:

1. **Fine-grained permissions**: Each service gets only what it needs
2. **No credential management**: No need to manage AWS credentials in pods
3. **Auditability**: Clear which service is making AWS API calls
4. **Security**: Temporary credentials with automatic rotation
5. **Kubernetes-native**: Uses standard Kubernetes Service Accounts

**IRSA is definitely the way to go for EKS!** It provides the security and granularity needed for production workloads.