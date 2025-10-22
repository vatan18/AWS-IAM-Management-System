#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[ROLE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

usage() {
    cat << 'EOF'
Create IAM Role

Usage: 
  # EC2 Instance Role
  $0 --profile PROFILE --role-name NAME --type ec2 [--description "DESC"] [--policy POLICY|--custom-policy JSON|--custom-policy-file FILE]
  
  # Lambda Function Role
  $0 --profile PROFILE --role-name NAME --type lambda [--description "DESC"] [--policy POLICY|--custom-policy JSON|--custom-policy-file FILE]
  
  # Cross-Account Role
  $0 --profile PROFILE --role-name NAME --type cross-account --trust-account ID [--external-id ID] [--description "DESC"] [--policy POLICY|--custom-policy JSON|--custom-policy-file FILE]
  
  # Service-Linked Role
  $0 --profile PROFILE --role-name NAME --type service-linked --service-name SERVICE [--description "DESC"] [--custom-suffix SUFFIX]
  
  # Custom Trust Role
  $0 --profile PROFILE --role-name NAME --type custom --trust-policy JSON|--trust-policy-file FILE [--description "DESC"] [--policy POLICY|--custom-policy JSON|--custom-policy-file FILE]

Arguments:
  --profile PROFILE          AWS CLI profile
  --role-name NAME           Role name
  --type TYPE                Role type: ec2, lambda, cross-account, service-linked, custom
  --trust-account ID         Trusted account ID (for cross-account)
  --external-id ID           External ID (for cross-account, optional)
  --service-name SERVICE     AWS service name (for service-linked roles)
  --custom-suffix SUFFIX     Custom suffix (for service-linked roles)
  --trust-policy JSON        Inline trust policy JSON
  --trust-policy-file FILE   Trust policy JSON file
  --policy POLICY            AWS managed policy name
  --custom-policy JSON       Inline access policy JSON
  --custom-policy-file FILE  Access policy JSON file
  --description "DESC"       Description (optional)

Examples:
  # EC2 Instance Role with S3 access
  $0 --profile 81 --role-name MyApp-EC2-Role --type ec2 --policy AmazonS3ReadOnlyAccess --description "EC2 role for S3 access"
  
  # Lambda Role with custom policy
  $0 --profile 81 --role-name MyLambda-Role --type lambda --custom-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:*","s3:GetObject"],"Resource":"*"}]}'
  
  # Cross-Account Role for Dev access
  $0 --profile 81 --role-name CrossAccount-Dev --type cross-account --trust-account 123456789012 --external-id dev2024 --policy ReadOnlyAccess
  
  # Service-Linked Role for ECS
  $0 --profile 81 --role-name MyECS-Role --type service-linked --service-name ecs.amazonaws.com --description "ECS service-linked role"

EOF
}

validate_json() {
    local json="$1"
    if ! jq empty <<< "$json" 2>/dev/null; then
        die "Invalid JSON policy"
    fi
}

read_policy_file() {
    local policy_file="$1"
    if [[ ! -f "$policy_file" ]]; then
        die "Policy file not found: $policy_file"
    fi
    
    local policy_content
    policy_content=$(cat "$policy_file")
    validate_json "$policy_content"
    echo "$policy_content"
}

create_trust_policy() {
    local role_type="$1" trust_account="$2" external_id="$3" service_name="$4" trust_policy="$5" trust_policy_file="$6"
    
    case "$role_type" in
        "ec2")
            echo '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "ec2.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }'
            ;;
        "lambda")
            echo '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "lambda.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }'
            ;;
        "cross-account")
            if [[ -n "$external_id" ]]; then
                cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${trust_account}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${external_id}"
                }
            }
        }
    ]
}
EOF
            else
                cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${trust_account}:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
            fi
            ;;
        "service-linked")
            cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "${service_name}"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
            ;;
        "custom")
            if [[ -n "$trust_policy" ]]; then
                echo "$trust_policy"
            elif [[ -n "$trust_policy_file" ]]; then
                read_policy_file "$trust_policy_file"
            fi
            ;;
        *)
            die "Unknown role type: $role_type"
            ;;
    esac
}

create_role() {
    local aws_cmd="$1" role_name="$2" trust_policy="$3" description="$4"
    
    local args=(
        --role-name "$role_name"
        --assume-role-policy-document "$trust_policy"
    )
    
    [[ -n "$description" ]] && args+=(--description "$description")
    
    $aws_cmd iam create-role "${args[@]}"
}

attach_managed_policy() {
    local aws_cmd="$1" role_name="$2" policy_name="$3"
    
    log "Attaching managed policy: $policy_name"
    $aws_cmd iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn "arn:aws:iam::aws:policy/$policy_name"
}

attach_custom_policy() {
    local aws_cmd="$1" role_name="$2" policy_content="$3"
    
    log "Attaching custom policy"
    
    local policy_file="/tmp/role-custom-policy-$$.json"
    echo "$policy_content" > "$policy_file"
    
    $aws_cmd iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "${role_name}Policy" \
        --policy-document "file://$policy_file"
    
    rm -f "$policy_file"
}

create_service_linked_role() {
    local aws_cmd="$1" service_name="$2" description="$3" custom_suffix="$4"
    
    local args=(--service-name "$service_name")
    [[ -n "$description" ]] && args+=(--description "$description")
    [[ -n "$custom_suffix" ]] && args+=(--custom-suffix "$custom_suffix")
    
    $aws_cmd iam create-service-linked-role "${args[@]}"
}

create_instance_profile() {
    local aws_cmd="$1" role_name="$2"
    
    log "Creating instance profile: $role_name"
    $aws_cmd iam create-instance-profile --instance-profile-name "$role_name"
    
    log "Adding role to instance profile"
    $aws_cmd iam add-role-to-instance-profile \
        --instance-profile-name "$role_name" \
        --role-name "$role_name"
}

main() {
    local profile="" role_name="" role_type="" trust_account="" external_id="" service_name="" custom_suffix=""
    local trust_policy="" trust_policy_file="" policy="" custom_policy="" custom_policy_file="" description=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --role-name) role_name="$2"; shift 2 ;;
            --type) role_type="$2"; shift 2 ;;
            --trust-account) trust_account="$2"; shift 2 ;;
            --external-id) external_id="$2"; shift 2 ;;
            --service-name) service_name="$2"; shift 2 ;;
            --custom-suffix) custom_suffix="$2"; shift 2 ;;
            --trust-policy) trust_policy="$2"; shift 2 ;;
            --trust-policy-file) trust_policy_file="$2"; shift 2 ;;
            --policy) policy="$2"; shift 2 ;;
            --custom-policy) custom_policy="$2"; shift 2 ;;
            --custom-policy-file) custom_policy_file="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" || -z "$role_name" || -z "$role_type" ]] && { usage; exit 1; }
    
    # Validate required parameters for each type
    case "$role_type" in
        "cross-account") [[ -z "$trust_account" ]] && { usage; die "--trust-account required for cross-account role"; } ;;
        "service-linked") [[ -z "$service_name" ]] && { usage; die "--service-name required for service-linked role"; } ;;
        "custom") [[ -z "$trust_policy" && -z "$trust_policy_file" ]] && { usage; die "--trust-policy or --trust-policy-file required for custom role"; } ;;
    esac
    
    # Validate policy options
    if [[ "$role_type" != "service-linked" ]]; then
        local policy_options=0
        [[ -n "$policy" ]] && ((policy_options++))
        [[ -n "$custom_policy" ]] && ((policy_options++))
        [[ -n "$custom_policy_file" ]] && ((policy_options++))
        
        [[ $policy_options -gt 1 ]] && { usage; die "Cannot specify multiple policy options"; }
    fi
    
    local aws_cmd="aws --profile $profile"
    local account_id=$($aws_cmd sts get-caller-identity --query "Account" --output text)
    
    log "Creating role: $role_name"
    log "Type: $role_type"
    log "Account: $account_id"
    [[ -n "$description" ]] && log "Description: $description"
    
    # Create role based on type
    if [[ "$role_type" == "service-linked" ]]; then
        create_service_linked_role "$aws_cmd" "$service_name" "$description" "$custom_suffix"
        log "✅ Service-linked role created: $role_name"
        return 0
    fi
    
    # Create trust policy
    local trust_policy_content
    trust_policy_content=$(create_trust_policy "$role_type" "$trust_account" "$external_id" "$service_name" "$trust_policy" "$trust_policy_file")
    
    # Create role
    create_role "$aws_cmd" "$role_name" "$trust_policy_content" "$description"
    
    # Attach access policies
    if [[ -n "$policy" ]]; then
        attach_managed_policy "$aws_cmd" "$role_name" "$policy"
    elif [[ -n "$custom_policy" ]]; then
        validate_json "$custom_policy"
        attach_custom_policy "$aws_cmd" "$role_name" "$custom_policy"
    elif [[ -n "$custom_policy_file" ]]; then
        local policy_content
        policy_content=$(read_policy_file "$custom_policy_file")
        attach_custom_policy "$aws_cmd" "$role_name" "$policy_content"
    fi
    
    # Create instance profile for EC2 roles
    if [[ "$role_type" == "ec2" ]]; then
        create_instance_profile "$aws_cmd" "$role_name"
    fi
    
    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"
    
    echo
    log "✅ Role created successfully"
    log "Role Name: $role_name"
    log "Role ARN: $role_arn"
    log "Type: $role_type"
    
    case "$role_type" in
        "ec2")
            log "Instance Profile: $role_name"
            echo
            log "Use with EC2:"
            echo "  aws ec2 run-instances --image-id ami-xxx --instance-type t3.micro --iam-instance-profile Name=$role_name"
            ;;
        "lambda")
            echo
            log "Use with Lambda:"
            echo "  aws lambda create-function --function-name my-function --role $role_arn --runtime python3.9 ..."
            ;;
        "cross-account")
            echo
            log "Trusted Account: $trust_account"
            [[ -n "$external_id" ]] && log "External ID: $external_id"
            echo
            log "Assume this role from trusted account:"
            echo "  aws sts assume-role --role-arn $role_arn --role-session-name MySession"
            [[ -n "$external_id" ]] && echo "  --external-id $external_id"
            ;;
        "custom")
            echo
            log "Custom trust policy configured"
            ;;
    esac
}

main "$@"