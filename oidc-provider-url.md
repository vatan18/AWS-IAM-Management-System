**OIDCProviderUrl** is the OpenID Connect (OIDC) issuer URL for your EKS cluster. It's a critical component that enables trust between AWS IAM and your Kubernetes cluster.

## What is OIDC Provider URL?

The OIDC Provider URL is a unique identifier for your EKS cluster's identity provider. It looks like this:

```
oidc.eks.region.amazonaws.com/id/CLUSTER_OIDC_ID
```

### Example:
```
oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDC6A2B0D1E2F3G4H5I6J7K8L9M0N
```

## How to Get OIDC Provider URL

### Method 1: AWS CLI
```bash
# Get OIDC issuer URL
aws eks describe-cluster \
    --name your-cluster-name \
    --query "cluster.identity.oidc.issuer" \
    --output text

# Example output:
# https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDC6A2B0D1E2F3G4H5I6J7K8L9M0N
```

### Method 2: Extract from ARN
```bash
CLUSTER_NAME="my-eks-cluster"
OIDC_ISSUER=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text)
OIDC_PROVIDER=$(echo $OIDC_ISSUER | sed 's|https://||')
echo $OIDC_PROVIDER
# Output: oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDC6A2B0D1E2F3G4H5I6J7K8L9M0N
```

### Method 3: CloudFormation Template with Auto-Discovery

Here's an updated template that automatically discovers the OIDC URL:

```yaml
# eks-irsa-complete.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'EKS IRSA with OIDC auto-discovery'

Parameters:
  Environment:
    Type: String
    Default: dev
  AppName:
    Type: String
  EKSClusterName:
    Type: String

Resources:
  # Custom Resource to get OIDC Provider URL
  OIDCProviderLookup:
    Type: Custom::OIDCProviderLookup
    Properties:
      ServiceToken: !GetAtt OIDCLookupFunction.Arn
      ClusterName: !Ref EKSClusterName

  # IAM OIDC Provider (creates the trust relationship)
  EKSOIDCProvider:
    Type: AWS::IAM::OIDCProvider
    Properties:
      Url: !GetAtt OIDCProviderLookup.OIDCIssuerUrl
      ClientIdList:
        - sts.amazonaws.com
      ThumbprintList:
        - 9e99a48a9960b14926bb7f3b02e22da2b0ab7280  # EKS OIDC thumbprint

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
              Federated: !Ref EKSOIDCProvider
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderLookup.OIDCProviderUrl}:sub: system:serviceaccount:default:my-app-serviceaccount
      Path: /

  # Custom Resource Lambda Function
  OIDCLookupFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub ${AppName}-oidc-lookup-${Environment}
      Runtime: python3.9
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 30
      Code:
        ZipFile: |
          import json
          import boto3
          import cfnresponse
          
          def get_oidc_provider(cluster_name):
              eks_client = boto3.client('eks')
              response = eks_client.describe_cluster(name=cluster_name)
              oidc_issuer = response['cluster']['identity']['oidc']['issuer']
              oidc_provider_url = oidc_issuer.replace('https://', '')
              return oidc_issuer, oidc_provider_url
          
          def handler(event, context):
              try:
                  if event['RequestType'] in ['Create', 'Update']:
                      cluster_name = event['ResourceProperties']['ClusterName']
                      oidc_issuer, oidc_provider_url = get_oidc_provider(cluster_name)
                      
                      response_data = {
                          'OIDCIssuerUrl': oidc_issuer,
                          'OIDCProviderUrl': oidc_provider_url
                      }
                      
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, response_data)
              except Exception as e:
                  print(f"Error: {str(e)}")
                  cfnresponse.send(event, context, cfnresponse.FAILED, {})

  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: EKSAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - eks:DescribeCluster
                Resource: "*"

Outputs:
  OIDCProviderArn:
    Description: OIDC Provider ARN
    Value: !Ref EKSOIDCProvider

  ServiceAccountRoleArn:
    Description: Service Account Role ARN
    Value: !GetAtt MyAppServiceAccountRole.Arn

  OIDCProviderUrl:
    Description: OIDC Provider URL
    Value: !GetAtt OIDCProviderLookup.OIDCProviderUrl
```

## Simplified Version (Manual OIDC Provider URL)

If you prefer to manually provide the OIDC URL:

```yaml
# eks-irsa-simple.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'EKS IRSA Simple Version'

Parameters:
  Environment:
    Type: String
  AppName:
    Type: String
  OIDCProviderUrl:
    Type: String
    Description: OIDC Provider URL (from: aws eks describe-cluster --name your-cluster --query cluster.identity.oidc.issuer --output text | sed 's|https://||')

Resources:
  # IAM OIDC Provider
  EKSOIDCProvider:
    Type: AWS::IAM::OIDCProvider
    Properties:
      Url: !Sub https://${OIDCProviderUrl}
      ClientIdList:
        - sts.amazonaws.com
      ThumbprintList:
        - 9e99a48a9960b14926bb7f3b02e22da2b0ab7280

  # Application Service Account Role
  AppServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-app-irsa-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Ref EKSOIDCProvider
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub ${OIDCProviderUrl}:sub: system:serviceaccount:default:app-serviceaccount
      Policies:
        - PolicyName: S3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                Resource: !Sub arn:aws:s3:::${AppName}-${Environment}/*

Outputs:
  ServiceAccountRoleArn:
    Value: !GetAtt AppServiceAccountRole.Arn
```

## Deployment Script with OIDC Discovery

```bash
#!/bin/bash
# deploy-eks-irsa.sh

set -euo pipefail

CLUSTER_NAME="my-eks-cluster"
ENVIRONMENT="dev"
APP_NAME="myapp"
REGION="us-east-1"

# Get OIDC Provider URL automatically
get_oidc_url() {
    local cluster_name=$1
    local oidc_issuer=$(aws eks describe-cluster \
        --name $cluster_name \
        --query "cluster.identity.oidc.issuer" \
        --output text)
    
    # Remove https:// prefix for the OIDC Provider URL
    echo $oidc_issuer | sed 's|https://||'
}

# Check if OIDC provider exists, create if not
ensure_oidc_provider() {
    local cluster_name=$1
    local oidc_url=$(get_oidc_url $cluster_name)
    local oidc_arn="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/$oidc_url"
    
    # Check if OIDC provider already exists
    if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" &>/dev/null; then
        echo "Creating OIDC Provider..."
        aws iam create-open-id-connect-provider \
            --url "https://$oidc_url" \
            --client-id-list "sts.amazonaws.com" \
            --thumbprint-list "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
    else
        echo "OIDC Provider already exists"
    fi
}

# Deploy IRSA Stack
deploy_irsa() {
    local oidc_url=$(get_oidc_url $CLUSTER_NAME)
    
    echo "OIDC Provider URL: $oidc_url"
    
    aws cloudformation deploy \
        --template-file eks-irsa-simple.yaml \
        --stack-name ${APP_NAME}-irsa-${ENVIRONMENT} \
        --parameter-overrides \
            Environment=$ENVIRONMENT \
            AppName=$APP_NAME \
            OIDCProviderUrl=$oidc_url \
        --capabilities CAPABILITY_NAMED_IAM
}

main() {
    echo "Setting up IRSA for EKS cluster: $CLUSTER_NAME"
    
    # Ensure OIDC provider exists
    ensure_oidc_provider $CLUSTER_NAME
    
    # Deploy IRSA stack
    deploy_irsa
    
    echo "IRSA setup completed!"
    echo "Service Account Role ARN:"
    aws cloudformation describe-stacks \
        --stack-name ${APP_NAME}-irsa-${ENVIRONMENT} \
        --query "Stacks[0].Outputs[?OutputKey=='ServiceAccountRoleArn'].OutputValue" \
        --output text
}

main "$@"
```

## How IRSA Works with OIDC:

1. **EKS Cluster** has an OIDC issuer URL
2. **AWS IAM** trusts this OIDC provider
3. **Kubernetes Service Account** is annotated with IAM role ARN
4. **Pods** using that service account get temporary AWS credentials
5. **AWS Services** verify the OIDC token from the pod

## Verification Commands:

```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Verify the role trust policy
aws iam get-role --role-name MyApp-irsa-dev

# Test in a pod
kubectl run test-pod --image=amazon/aws-cli --serviceaccount=my-app-serviceaccount --command -- sleep 3600
kubectl exec test-pod -- aws sts get-caller-identity

# Should show something like:
# {
#   "UserId": "AROAEXAMPLE:aws-iam-authenticator-1234567890",
#   "Account": "123456789012",
#   "Arn": "arn:aws:sts::123456789012:assumed-role/MyApp-irsa-dev/aws-iam-authenticator-1234567890"
# }
```

## Key Points:

- **OIDC Provider URL** is unique to each EKS cluster
- It establishes trust between AWS IAM and your Kubernetes cluster
- Required for IRSA to work
- Automatically created when you create an EKS cluster
- You need to create the IAM OIDC Provider resource in your AWS account

The OIDC Provider URL is the bridge that allows your Kubernetes pods to securely assume IAM roles without storing long-term credentials!