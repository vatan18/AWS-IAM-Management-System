### Here's a comprehensive CloudFormation template collection covering various IAM role scenarios following least privilege principles:

## 1. EC2 Instance Role Template

```yaml
# ec2-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'EC2 Instance Role with Least Privilege Access'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Description: Deployment environment
  
  AppName:
    Type: String
    Description: Application name for resource naming

Resources:
  # EC2 Instance Role
  EC2InstanceRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-EC2-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: Application
          Value: !Ref AppName

  # S3 Access Policy
  S3AccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-S3-Access-${Environment}
      Roles:
        - !Ref EC2InstanceRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          # Read-only access to specific S3 buckets
          - Effect: Allow
            Action:
              - s3:GetObject
              - s3:GetObjectVersion
              - s3:ListBucket
            Resource:
              - !Sub arn:aws:s3:::${AppName}-config-${Environment}
              - !Sub arn:aws:s3:::${AppName}-config-${Environment}/*
          
          # Write access to specific prefix
          - Effect: Allow
            Action:
              - s3:PutObject
              - s3:DeleteObject
            Resource: !Sub arn:aws:s3:::${AppName}-uploads-${Environment}/*

  # Secrets Manager Policy
  SecretsManagerPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-Secrets-Access-${Environment}
      Roles:
        - !Ref EC2InstanceRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - secretsmanager:GetSecretValue
              - secretsmanager:DescribeSecret
            Resource:
              - !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${AppName}/${Environment}/*
            Condition:
              StringEquals:
                secretsmanager:ResourceTag/Environment: !Ref Environment

  # CloudFront Policy (for signed URLs/private content)
  CloudFrontPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-CloudFront-Access-${Environment}
      Roles:
        - !Ref EC2InstanceRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - cloudfront:CreateSignedUrl
              - cloudfront:CreateSignedCookie
            Resource: !Sub arn:aws:cloudfront::${AWS::AccountId}:distribution/*
            Condition:
              StringEquals:
                aws:ResourceTag/Environment: !Ref Environment

  # KMS Decryption Policy
  KMSDecryptPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-KMS-Decrypt-${Environment}
      Roles:
        - !Ref EC2InstanceRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - kms:Decrypt
              - kms:DescribeKey
            Resource: !GetAtt KMSKey.Arn

  # KMS Key for encryption
  KMSKey:
    Type: AWS::KMS::Key
    Properties:
      Description: !Sub KMS key for ${AppName} in ${Environment}
      KeyPolicy:
        Version: '2012-10-17'
        Id: key-default-1
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub arn:aws:iam::${AWS::AccountId}:root
            Action: kms:*
            Resource: '*'
          - Sid: Allow EC2 Role Access
            Effect: Allow
            Principal:
              AWS: !GetAtt EC2InstanceRole.Arn
            Action:
              - kms:Decrypt
              - kms:DescribeKey
            Resource: '*'
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: Application
          Value: !Ref AppName

  KMSKeyAlias:
    Type: AWS::KMS::Alias
    Properties:
      AliasName: !Sub alias/${AppName}-${Environment}
      TargetKeyId: !Ref KMSKey

  # Instance Profile for EC2
  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      InstanceProfileName: !Sub ${AppName}-EC2-Profile-${Environment}
      Roles:
        - !Ref EC2InstanceRole

Outputs:
  EC2RoleArn:
    Description: EC2 Instance Role ARN
    Value: !GetAtt EC2InstanceRole.Arn
    Export:
      Name: !Sub ${AppName}-EC2RoleArn-${Environment}

  EC2InstanceProfileName:
    Description: EC2 Instance Profile Name
    Value: !Ref EC2InstanceProfile
    Export:
      Name: !Sub ${AppName}-EC2Profile-${Environment}

  KMSKeyArn:
    Description: KMS Key ARN for decryption
    Value: !GetAtt KMSKey.Arn
    Export:
      Name: !Sub ${AppName}-KMSKey-${Environment}
```

## 2. ECS Task Role Template

```yaml
# ecs-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'ECS Task Role with Least Privilege Access'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
  
  AppName:
    Type: String
  
  ECSClusterName:
    Type: String
    Description: ECS Cluster name

Resources:
  # ECS Task Execution Role
  ECSExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-ECS-Execution-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # ECS Task Role
  ECSTaskRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-ECS-Task-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # ECR Access Policy
  ECRAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-ECR-Access-${Environment}
      Roles:
        - !Ref ECSTaskRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - ecr:GetAuthorizationToken
              - ecr:BatchCheckLayerAvailability
              - ecr:GetDownloadUrlForLayer
              - ecr:BatchGetImage
            Resource: '*'

  # DynamoDB Access Policy
  DynamoDBAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-DynamoDB-Access-${Environment}
      Roles:
        - !Ref ECSTaskRole
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
            Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${AppName}-${Environment}-*

  # SQS Access Policy
  SQSAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-SQS-Access-${Environment}
      Roles:
        - !Ref ECSTaskRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - sqs:SendMessage
              - sqs:ReceiveMessage
              - sqs:DeleteMessage
              - sqs:GetQueueAttributes
            Resource: !Sub arn:aws:sqs:${AWS::Region}:${AWS::AccountId}:${AppName}-${Environment}-*

  # CloudWatch Logs Policy
  CloudWatchLogsPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-CW-Logs-${Environment}
      Roles:
        - !Ref ECSTaskRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - logs:CreateLogStream
              - logs:PutLogEvents
              - logs:CreateLogGroup
            Resource: !Sub arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/ecs/${AppName}-${Environment}:*

  # X-Ray Tracing Policy
  XRayTracingPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-XRay-Tracing-${Environment}
      Roles:
        - !Ref ECSTaskRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - xray:PutTraceSegments
              - xray:PutTelemetryRecords
              - xray:GetSamplingRules
              - xray:GetSamplingTargets
            Resource: '*'

Outputs:
  ECSExecutionRoleArn:
    Description: ECS Execution Role ARN
    Value: !GetAtt ECSExecutionRole.Arn
    Export:
      Name: !Sub ${AppName}-ECSExecutionRole-${Environment}

  ECSTaskRoleArn:
    Description: ECS Task Role ARN
    Value: !GetAtt ECSTaskRole.Arn
    Export:
      Name: !Sub ${AppName}-ECSTaskRole-${Environment}
```

## 3. EKS Node Group & Pod Roles Template

```yaml
# eks-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'EKS Node Group and Pod Roles with Least Privilege'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
  
  AppName:
    Type: String
  
  EKSClusterName:
    Type: String
    Description: EKS Cluster name

Resources:
  # EKS Node Group Role
  EKSNodeGroupRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-EKS-NodeGroup-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # EKS Node Group Custom Policies
  EKSNodeGroupCustomPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-EKS-Node-Custom-${Environment}
      Roles:
        - !Ref EKSNodeGroupRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          # Autoscaling permissions
          - Effect: Allow
            Action:
              - autoscaling:DescribeAutoScalingGroups
              - autoscaling:DescribeAutoScalingInstances
              - autoscaling:SetDesiredCapacity
              - autoscaling:TerminateInstanceInAutoScalingGroup
            Resource: '*'
          
          # EC2 permissions for node management
          - Effect: Allow
            Action:
              - ec2:DescribeInstances
              - ec2:DescribeInstanceTypes
              - ec2:DescribeTags
            Resource: '*'

  # EKS Pod Execution Role (for Fargate)
  EKSPodExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-EKS-Pod-Execution-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: pods.eks.amazonaws.com
            Action:
              - sts:AssumeRole
              - sts:TagSession
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # IAM Role for Service Account (IRSA)
  EKSServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-EKS-IRSA-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub arn:aws:iam::${AWS::AccountId}:oidc-provider/oidc.eks.${AWS::Region}.amazonaws.com/id/${EKSClusterOIDCId}
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                !Sub oidc.eks.${AWS::Region}.amazonaws.com/id/${EKSClusterOIDCId}:aud: sts.amazonaws.com
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # S3 Access Policy for IRSA
  EKSS3AccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-EKS-S3-Access-${Environment}
      Roles:
        - !Ref EKSServiceAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:GetObject
              - s3:PutObject
              - s3:ListBucket
            Resource:
              - !Sub arn:aws:s3:::${AppName}-data-${Environment}
              - !Sub arn:aws:s3:::${AppName}-data-${Environment}/*

  # DynamoDB Policy for IRSA
  EKSDynamoDBPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-EKS-DynamoDB-${Environment}
      Roles:
        - !Ref EKSServiceAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - dynamodb:Query
              - dynamodb:Scan
              - dynamodb:GetItem
              - dynamodb:PutItem
              - dynamodb:UpdateItem
              - dynamodb:DeleteItem
            Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${AppName}-${Environment}-*

  # Secrets Manager Policy for IRSA
  EKSSecretsPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-EKS-Secrets-${Environment}
      Roles:
        - !Ref EKSServiceAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - secretsmanager:GetSecretValue
              - secretsmanager:DescribeSecret
            Resource:
              - !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${AppName}/${Environment}/*

Outputs:
  EKSNodeGroupRoleArn:
    Description: EKS Node Group Role ARN
    Value: !GetAtt EKSNodeGroupRole.Arn
    Export:
      Name: !Sub ${AppName}-EKSNodeRole-${Environment}

  EKSPodExecutionRoleArn:
    Description: EKS Pod Execution Role ARN
    Value: !GetAtt EKSPodExecutionRole.Arn
    Export:
      Name: !Sub ${AppName}-EKSPodRole-${Environment}

  EKSServiceAccountRoleArn:
    Description: EKS Service Account Role ARN
    Value: !GetAtt EKSServiceAccountRole.Arn
    Export:
      Name: !Sub ${AppName}-EKSIRSA-${Environment}
```

## 4. Cross-Account Role Template

```yaml
# cross-account-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Cross-Account IAM Role'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
  
  AppName:
    Type: String
  
  TrustedAccountId:
    Type: String
    Description: AWS Account ID that can assume this role
  
  ExternalId:
    Type: String
    Description: External ID for additional security (optional)
    Default: ''

Resources:
  CrossAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-CrossAccount-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub arn:aws:iam::${TrustedAccountId}:root
            Action: sts:AssumeRole
            Condition: !If 
              - HasExternalId
              - StringEquals:
                  sts:ExternalId: !Ref ExternalId
              - !Ref "AWS::NoValue"
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: CrossAccount
          Value: !Ref TrustedAccountId

  # ReadOnly Access Policy
  CrossAccountReadOnlyPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-CrossAccount-ReadOnly-${Environment}
      Roles:
        - !Ref CrossAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:Get*
              - s3:List*
              - dynamodb:GetItem
              - dynamodb:Scan
              - dynamodb:Query
              - dynamodb:DescribeTable
              - ec2:Describe*
              - cloudwatch:Get*
              - cloudwatch:List*
            Resource: '*'

  # Specific Resource Access Policy
  CrossAccountSpecificAccess:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-CrossAccount-Specific-${Environment}
      Roles:
        - !Ref CrossAccountRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          # Access to specific S3 buckets
          - Effect: Allow
            Action:
              - s3:GetObject
              - s3:PutObject
            Resource: !Sub arn:aws:s3:::${AppName}-shared-${Environment}/*
          
          # Access to specific DynamoDB tables
          - Effect: Allow
            Action:
              - dynamodb:GetItem
              - dynamodb:PutItem
              - dynamodb:UpdateItem
            Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${AppName}-shared-${Environment}

Conditions:
  HasExternalId: !Not [!Equals [!Ref ExternalId, '']]

Outputs:
  CrossAccountRoleArn:
    Description: Cross Account Role ARN
    Value: !GetAtt CrossAccountRole.Arn
    Export:
      Name: !Sub ${AppName}-CrossAccountRole-${Environment}
```

## 5. Lambda Execution Role Template

```yaml
# lambda-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lambda Execution Role with Least Privilege'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
  
  AppName:
    Type: String

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${AppName}-Lambda-Role-${Environment}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      Path: /
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # Basic Lambda Execution Policy
  LambdaBasicExecution:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-Lambda-Basic-${Environment}
      Roles:
        - !Ref LambdaExecutionRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - logs:CreateLogGroup
              - logs:CreateLogStream
              - logs:PutLogEvents
            Resource: !Sub arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${AppName}-${Environment}-*:*

  # DynamoDB Access for Lambda
  LambdaDynamoDBPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-Lambda-DynamoDB-${Environment}
      Roles:
        - !Ref LambdaExecutionRole
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
            Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${AppName}-${Environment}-*

  # S3 Access for Lambda
  LambdaS3Policy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-Lambda-S3-${Environment}
      Roles:
        - !Ref LambdaExecutionRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:GetObject
              - s3:PutObject
              - s3:DeleteObject
            Resource: !Sub arn:aws:s3:::${AppName}-${Environment}-*/*

  # SNS/SQS Access for Lambda
  LambdaEventPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-Lambda-Events-${Environment}
      Roles:
        - !Ref LambdaExecutionRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - sns:Publish
              - sqs:SendMessage
              - sqs:ReceiveMessage
              - sqs:DeleteMessage
            Resource: !Sub arn:aws:sns:${AWS::Region}:${AWS::AccountId}:${AppName}-${Environment}-*
          - Effect: Allow
            Action:
              - sqs:SendMessage
              - sqs:ReceiveMessage
              - sqs:DeleteMessage
            Resource: !Sub arn:aws:sqs:${AWS::Region}:${AWS::AccountId}:${AppName}-${Environment}-*

  # VPC Access for Lambda
  LambdaVPCPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub ${AppName}-Lambda-VPC-${Environment}
      Roles:
        - !Ref LambdaExecutionRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - ec2:CreateNetworkInterface
              - ec2:DescribeNetworkInterfaces
              - ec2:DeleteNetworkInterface
              - ec2:AttachNetworkInterface
              - ec2:DetachNetworkInterface
            Resource: '*'

Outputs:
  LambdaExecutionRoleArn:
    Description: Lambda Execution Role ARN
    Value: !GetAtt LambdaExecutionRole.Arn
    Export:
      Name: !Sub ${AppName}-LambdaRole-${Environment}
```

## 6. Master Template for Deployment

```yaml
# master-role-stack.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Master Stack for IAM Roles Deployment'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: dev
  
  AppName:
    Type: String
    Default: MyApplication
  
  DeployEC2Role:
    Type: String
    AllowedValues: [true, false]
    Default: 'true'
  
  DeployECSRole:
    Type: String
    AllowedValues: [true, false]
    Default: 'false'
  
  DeployEKSRole:
    Type: String
    AllowedValues: [true, false]
    Default: 'false'
  
  DeployLambdaRole:
    Type: String
    AllowedValues: [true, false]
    Default: 'true'

Resources:
  # Nested stacks for each role type
  EC2RoleStack:
    Type: AWS::CloudFormation::Stack
    Condition: DeployEC2
    Properties:
      TemplateURL: ./ec2-role.yaml
      Parameters:
        Environment: !Ref Environment
        AppName: !Ref AppName

  ECSRoleStack:
    Type: AWS::CloudFormation::Stack
    Condition: DeployECS
    Properties:
      TemplateURL: ./ecs-role.yaml
      Parameters:
        Environment: !Ref Environment
        AppName: !Ref AppName

  EKSRoleStack:
    Type: AWS::CloudFormation::Stack
    Condition: DeployEKS
    Properties:
      TemplateURL: ./eks-role.yaml
      Parameters:
        Environment: !Ref Environment
        AppName: !Ref AppName

  LambdaRoleStack:
    Type: AWS::CloudFormation::Stack
    Condition: DeployLambda
    Properties:
      TemplateURL: ./lambda-role.yaml
      Parameters:
        Environment: !Ref Environment
        AppName: !Ref AppName

Conditions:
  DeployEC2: !Equals [!Ref DeployEC2Role, 'true']
  DeployECS: !Equals [!Ref DeployECSRole, 'true']
  DeployEKS: !Equals [!Ref DeployEKSRole, 'true']
  DeployLambda: !Equals [!Ref DeployLambdaRole, 'true']

Outputs:
  EC2RoleArn:
    Condition: DeployEC2
    Description: EC2 Role ARN
    Value: !GetAtt EC2RoleStack.Outputs.EC2RoleArn

  ECSExecutionRoleArn:
    Condition: DeployECS
    Description: ECS Execution Role ARN
    Value: !GetAtt ECSRoleStack.Outputs.ECSExecutionRoleArn

  EKSServiceAccountRoleArn:
    Condition: DeployEKS
    Description: EKS Service Account Role ARN
    Value: !GetAtt EKSRoleStack.Outputs.EKSServiceAccountRoleArn

  LambdaExecutionRoleArn:
    Condition: DeployLambda
    Description: Lambda Execution Role ARN
    Value: !GetAtt LambdaRoleStack.Outputs.LambdaExecutionRoleArn
```

## Deployment Commands

```bash
# Deploy specific roles
aws cloudformation deploy \
  --template-file master-role-stack.yaml \
  --stack-name myapp-iam-roles \
  --parameter-overrides \
      Environment=dev \
      AppName=MyApp \
      DeployEC2Role=true \
      DeployLambdaRole=true \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy individual roles
aws cloudformation deploy \
  --template-file ec2-role.yaml \
  --stack-name myapp-ec2-role \
  --parameter-overrides Environment=dev AppName=MyApp \
  --capabilities CAPABILITY_NAMED_IAM

# Update existing resources with new roles
aws cloudformation update-stack \
  --stack-name myapp-ec2-instances \
  --template-body file://ec2-with-role.yaml \
  --parameters ParameterKey=InstanceProfile,ParameterValue=MyApp-EC2-Profile-dev \
  --capabilities CAPABILITY_NAMED_IAM
```

## Key Benefits of This Approach:

1. **Least Privilege**: Each policy grants only necessary permissions
2. **Environment Separation**: Different permissions per environment
3. **Reusability**: Templates can be reused across projects
4. **Auditability**: All changes are tracked in CloudFormation
5. **Security**: Resource-level permissions with conditions
6. **Scalability**: Easy to add new services and permissions
7. **Compliance**: Easy to demonstrate compliance requirements

This approach ensures that your IAM roles are managed as infrastructure-as-code, following security best practices and making your AWS environment more maintainable and secure.

## 1. Attaching to Existing EC2 Instances

### Method A: AWS CLI
```bash
# Get existing instance ID
INSTANCE_ID="i-1234567890abcdef0"

# Attach instance profile
aws ec2 associate-iam-instance-profile \
    --instance-id $INSTANCE_ID \
    --iam-instance-profile Name=MyApp-EC2-Profile-dev

# Check current association
aws ec2 describe-iam-instance-profile-associations

# Replace existing profile
aws ec2 replace-iam-instance-profile-association \
    --association-id iip-assoc-1234567890abcdef0 \
    --iam-instance-profile Name=MyApp-EC2-Profile-dev
```

### Method B: Update via CloudFormation (if instance is managed by CFN)
```yaml
# ec2-instance-with-role.yaml
Resources:
  ExistingEC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceId: i-1234567890abcdef0  # Reference existing instance
      IamInstanceProfile: !Ref EC2InstanceProfile
      # Other existing properties...
```

## 2. Attaching to Existing ECS Services

### Method A: Update ECS Service
```bash
# Update existing ECS service with new task role
aws ecs update-service \
    --cluster my-cluster \
    --service my-service \
    --task-definition new-task-definition-with-role

# Create new task definition with the role
aws ecs register-task-definition \
    --family my-task-family \
    --task-role-arn arn:aws:iam::123456789012:role/MyApp-ECS-Task-Role-dev \
    --execution-role-arn arn:aws:iam::123456789012:role/MyApp-ECS-Execution-Role-dev \
    --container-definitions file://container-def.json
```

### Method B: CloudFormation for Existing ECS Service
```yaml
# ecs-service-update.yaml
Resources:
  ExistingECSService:
    Type: AWS::ECS::Service
    Properties:
      ServiceName: my-existing-service
      Cluster: my-cluster
      TaskDefinition: !Ref NewTaskDefinition
      # Other existing properties...

  NewTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: my-task-family
      TaskRoleArn: !ImportValue MyApp-ECSTaskRole-dev
      ExecutionRoleArn: !ImportValue MyApp-ECSExecutionRole-dev
      ContainerDefinitions:
        # Your container definitions...
```

## 3. Attaching to Existing Lambda Functions

### Method A: AWS CLI Update
```bash
# Update Lambda function role
aws lambda update-function-configuration \
    --function-name my-existing-function \
    --role arn:aws:iam::123456789012:role/MyApp-Lambda-Role-dev

# For multiple functions
FUNCTIONS=("function1" "function2" "function3")
ROLE_ARN="arn:aws:iam::123456789012:role/MyApp-Lambda-Role-dev"

for FUNCTION in "${FUNCTIONS[@]}"; do
    aws lambda update-function-configuration \
        --function-name $FUNCTION \
        --role $ROLE_ARN
    echo "Updated $FUNCTION"
done
```

### Method B: CloudFormation Custom Resource
```yaml
# lambda-role-attachment.yaml
Resources:
  LambdaRoleAttachment:
    Type: Custom::LambdaRoleAttachment
    Properties:
      ServiceToken: !GetAtt LambdaRoleAttachmentFunction.Arn
      FunctionName: my-existing-lambda
      RoleArn: !ImportValue MyApp-LambdaRole-dev

  LambdaRoleAttachmentFunction:
    Type: AWS::Lambda::Function
    Properties:
      Runtime: python3.9
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          import boto3
          import cfnresponse
          def handler(event, context):
              lambda_client = boto3.client('lambda')
              if event['RequestType'] in ['Create', 'Update']:
                  lambda_client.update_function_configuration(
                      FunctionName=event['ResourceProperties']['FunctionName'],
                      Role=event['ResourceProperties']['RoleArn']
                  )
              cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
```

## 4. Attaching to Existing EKS Pods/ServiceAccounts

### Method A: Update Kubernetes ServiceAccount
```yaml
# eks-serviceaccount-update.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-serviceaccount
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MyApp-EKS-IRSA-dev
```

### Method B: Patch existing ServiceAccount
```bash
# Patch existing service account
kubectl patch serviceaccount my-app-serviceaccount -p \
    '{"metadata": {"annotations": {"eks.amazonaws.com/role-arn": "arn:aws:iam::123456789012:role/MyApp-EKS-IRSA-dev"}}}'

# Update deployment to use the service account
kubectl patch deployment my-app -p \
    '{"spec": {"template": {"spec": {"serviceAccountName": "my-app-serviceaccount"}}}}'
```

## 5. Comprehensive Attachment Template

Here's a complete CloudFormation template for attaching roles to existing resources:

```yaml
# attach-roles-to-existing-resources.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Attach IAM roles to existing AWS resources'

Parameters:
  Environment:
    Type: String
    Default: dev
  
  AppName:
    Type: String
  
  # Existing resource identifiers
  ExistingEC2InstanceId:
    Type: String
    Default: ""
  
  ExistingLambdaFunctionName:
    Type: String
    Default: ""
  
  ExistingECSServiceName:
    Type: String
    Default: ""
  
  ExistingEKSClusterName:
    Type: String
    Default: ""

Resources:
  # EC2 Instance Profile Association
  EC2InstanceProfileAssociation:
    Type: AWS::EC2::Instance
    Condition: HasEC2Instance
    Properties:
      InstanceId: !Ref ExistingEC2InstanceId
      IamInstanceProfile: !ImportValue 
        Fn::Sub: "${AppName}-EC2Profile-${Environment}"

  # Lambda Function Role Update (Custom Resource)
  LambdaRoleUpdate:
    Type: Custom::LambdaRoleAttachment
    Condition: HasLambdaFunction
    Properties:
      ServiceToken: !GetAtt RoleAttachmentFunction.Arn
      FunctionName: !Ref ExistingLambdaFunctionName
      RoleArn: !ImportValue 
        Fn::Sub: "${AppName}-LambdaRole-${Environment}"

  # ECS Service Update
  ECSServiceUpdate:
    Type: AWS::ECS::Service
    Condition: HasECSService
    Properties:
      ServiceName: !Ref ExistingECSServiceName
      Cluster: !If [HasEKSCluster, !Ref ExistingEKSClusterName, "default"]
      TaskDefinition: !Ref NewTaskDefinition
      DesiredCount: 1  # Maintain current count

  NewTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Condition: HasECSService
    Properties:
      Family: !Sub "${AppName}-${Environment}-task"
      TaskRoleArn: !ImportValue 
        Fn::Sub: "${AppName}-ECSTaskRole-${Environment}"
      ExecutionRoleArn: !ImportValue 
        Fn::Sub: "${AppName}-ECSExecutionRole-${Environment}"
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      Cpu: 256
      Memory: 512
      ContainerDefinitions:
        - Name: !Sub "${AppName}-${Environment}"
          Image: !Sub "${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/${AppName}:latest"
          PortMappings:
            - ContainerPort: 80

  # Custom Resource Lambda Function
  RoleAttachmentFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${AppName}-Role-Attachment-${Environment}"
      Runtime: python3.9
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 300
      Code:
        ZipFile: |
          import json
          import boto3
          import cfnresponse
          
          def update_lambda_role(function_name, role_arn):
              lambda_client = boto3.client('lambda')
              response = lambda_client.update_function_configuration(
                  FunctionName=function_name,
                  Role=role_arn
              )
              return response
          
          def handler(event, context):
              try:
                  if event['RequestType'] in ['Create', 'Update']:
                      function_name = event['ResourceProperties']['FunctionName']
                      role_arn = event['ResourceProperties']['RoleArn']
                      
                      print(f"Updating {function_name} with role {role_arn}")
                      response = update_lambda_role(function_name, role_arn)
                      print(f"Success: {response}")
                      
                  cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
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
        - PolicyName: LambdaUpdateAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - lambda:UpdateFunctionConfiguration
                  - lambda:GetFunction
                Resource: "*"

Conditions:
  HasEC2Instance: !Not [!Equals [!Ref ExistingEC2InstanceId, ""]]
  HasLambdaFunction: !Not [!Equals [!Ref ExistingLambdaFunctionName, ""]]
  HasECSService: !Not [!Equals [!Ref ExistingECSServiceName, ""]]
  HasEKSCluster: !Not [!Equals [!Ref ExistingEKSClusterName, ""]]

Outputs:
  EC2InstanceUpdated:
    Condition: HasEC2Instance
    Description: EC2 instance role updated
    Value: !Ref ExistingEC2InstanceId

  LambdaFunctionUpdated:
    Condition: HasLambdaFunction
    Description: Lambda function role updated
    Value: !Ref ExistingLambdaFunctionName

  ECSServiceUpdated:
    Condition: HasECSService
    Description: ECS service role updated
    Value: !Ref ExistingECSServiceName
```

## 6. Deployment Script for Existing Resources

```bash
#!/bin/bash
# attach-roles-to-existing.sh

set -euo pipefail

ENVIRONMENT="dev"
APP_NAME="MyApp"
STACK_NAME="${APP_NAME}-role-attachments"

# Array of existing resources
EC2_INSTANCES=("i-1234567890abcdef0" "i-0987654321abcdef0")
LAMBDA_FUNCTIONS=("my-function-1" "my-function-2")
ECS_SERVICES=("my-ecs-service")

# Deploy the attachment stack
deploy_attachments() {
    echo "Deploying role attachments to existing resources..."
    
    aws cloudformation deploy \
        --template-file attach-roles-to-existing-resources.yaml \
        --stack-name $STACK_NAME \
        --parameter-overrides \
            Environment=$ENVIRONMENT \
            AppName=$APP_NAME \
            ExistingEC2InstanceId=${EC2_INSTANCES[0]} \
            ExistingLambdaFunctionName=${LAMBDA_FUNCTIONS[0]} \
            ExistingECSServiceName=${ECS_SERVICES[0]} \
        --capabilities CAPABILITY_NAMED_IAM
    
    echo "Role attachments deployed successfully!"
}

# Alternative: Direct AWS CLI updates
update_lambda_functions() {
    ROLE_ARN=$(aws cloudformation describe-stacks \
        --stack-name ${APP_NAME}-iam-roles \
        --query "Stacks[0].Outputs[?OutputKey=='LambdaExecutionRoleArn'].OutputValue" \
        --output text)
    
    for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
        echo "Updating Lambda function: $FUNCTION"
        aws lambda update-function-configuration \
            --function-name $FUNCTION \
            --role $ROLE_ARN
    done
}

update_ec2_instances() {
    PROFILE_NAME="${APP_NAME}-EC2-Profile-${ENVIRONMENT}"
    
    for INSTANCE in "${EC2_INSTANCES[@]}"; do
        echo "Updating EC2 instance: $INSTANCE"
        
        # Check existing association
        EXISTING_ASSOC=$(aws ec2 describe-iam-instance-profile-associations \
            --filters "Name=instance-id,Values=$INSTANCE" \
            --query "IamInstanceProfileAssociations[0].AssociationId" \
            --output text)
        
        if [ "$EXISTING_ASSOC" != "None" ]; then
            # Replace existing association
            aws ec2 replace-iam-instance-profile-association \
                --association-id $EXISTING_ASSOC \
                --iam-instance-profile Name=$PROFILE_NAME
        else
            # Create new association
            aws ec2 associate-iam-instance-profile \
                --instance-id $INSTANCE \
                --iam-instance-profile Name=$PROFILE_NAME
        fi
    done
}

# Main execution
main() {
    case "${1:-}" in
        "cfn")
            deploy_attachments
            ;;
        "direct")
            update_lambda_functions
            update_ec2_instances
            ;;
        *)
            echo "Usage: $0 {cfn|direct}"
            echo "  cfn    - Use CloudFormation"
            echo "  direct - Use direct AWS CLI"
            exit 1
            ;;
    esac
}

main "$@"
```

## 7. Verification Script

```bash
#!/bin/bash
# verify-role-attachments.sh

verify_ec2_roles() {
    echo "=== Verifying EC2 Instance Roles ==="
    
    for INSTANCE in "${EC2_INSTANCES[@]}"; do
        PROFILE=$(aws ec2 describe-iam-instance-profile-associations \
            --filters "Name=instance-id,Values=$INSTANCE" \
            --query "IamInstanceProfileAssociations[0].IamInstanceProfile.Arn" \
            --output text)
        
        echo "Instance $INSTANCE: $PROFILE"
    done
}

verify_lambda_roles() {
    echo "=== Verifying Lambda Function Roles ==="
    
    for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
        ROLE=$(aws lambda get-function \
            --function-name $FUNCTION \
            --query "Configuration.Role" \
            --output text)
        
        echo "Lambda $FUNCTION: $ROLE"
    done
}

verify_ecs_roles() {
    echo "=== Verifying ECS Task Roles ==="
    
    for SERVICE in "${ECS_SERVICES[@]}"; do
        TASK_DEF=$(aws ecs describe-services \
            --cluster $CLUSTER \
            --services $SERVICE \
            --query "services[0].taskDefinition" \
            --output text)
        
        ROLE=$(aws ecs describe-task-definition \
            --task-definition $TASK_DEF \
            --query "taskDefinition.taskRoleArn" \
            --output text)
        
        echo "ECS Service $SERVICE: $ROLE"
    done
}
```

## Key Points:

1. **EC2 Instances**: Use instance profile associations
2. **Lambda Functions**: Update function configuration
3. **ECS Services**: Update task definitions
4. **EKS Pods**: Update service accounts and deployments
5. **RDS/Other Services**: Use resource-based policies where applicable

**Choose the method that best fits your infrastructure management style:** CloudFormation for IaC consistency or direct AWS CLI for quick updates.