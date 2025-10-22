#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

check_aws_cli() {
    local profile="${1:-}"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    if ! command -v aws &> /dev/null; then
        die "AWS CLI is not installed"
    fi
    
    if ! $aws_cmd sts get-caller-identity &> /dev/null; then
        die "AWS CLI not configured for profile: $profile"
    fi
}

create_group_if_not_exists() {
    local group_name="$1"
    local profile="$2"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    if $aws_cmd iam get-group --group-name "$group_name" &> /dev/null; then
        log "Group '$group_name' already exists"
    else
        log "Creating group: $group_name"
        $aws_cmd iam create-group --group-name "$group_name"
    fi
}

attach_policy_to_group() {
    local group_name="$1"
    local policy_arn="$2"
    local profile="$3"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    log "Attaching policy $policy_arn to group $group_name"
    $aws_cmd iam attach-group-policy --group-name "$group_name" --policy-arn "$policy_arn"
}

create_custom_developer_policy() {
    local profile="$1"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    local policy_document='{
        "Version": "2012-10-17",
        "Statement": [
            {
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
                    "ecr:PutImage",
                    "eks:DescribeCluster",
                    "eks:ListClusters"
                ],
                "Resource": "*"
            }
        ]
    }'
    
    echo "$policy_document" > /tmp/developer-custom-policy.json
    
    if ! $aws_cmd iam get-policy --policy-arn "arn:aws:iam::$(aws_account_id $profile):policy/DeveloperCustomAccess" &> /dev/null; then
        log "Creating custom developer policy"
        $aws_cmd iam create-policy \
            --policy-name DeveloperCustomAccess \
            --policy-document file:///tmp/developer-custom-policy.json \
            --description "Custom permissions for developers: ECR + EKS read"
    fi
    
    rm -f /tmp/developer-custom-policy.json
}

aws_account_id() {
    local profile="${1:-}"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    $aws_cmd sts get-caller-identity --query "Account" --output text
}

main() {
    local profile=""
    
    # Parse profile flag
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                profile="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    check_aws_cli "$profile"
    
    log "Setting up IAM groups for AWS Account: $(aws_account_id "$profile")"
    
    # Define groups and their policies
    declare -A group_policies=(
        ["Developers"]="ReadOnlyAccess"
        ["S3-Readers"]="AmazonS3ReadOnlyAccess"
        ["EKS-Deployers"]="AmazonEKSClusterPolicy"
        ["Read-Only-Users"]="ReadOnlyAccess"
        ["Power-Users"]="PowerUserAccess"
        ["Admins"]="AdministratorAccess"
    )
    
    # Create custom developer policy
    create_custom_developer_policy "$profile"
    
    # Create groups and attach policies
    for group in "${!group_policies[@]}"; do
        policy="${group_policies[$group]}"
        
        create_group_if_not_exists "$group" "$profile"
        
        # Attach AWS managed policy
        attach_policy_to_group "$group" "arn:aws:iam::aws:policy/$policy" "$profile"
        
        # Attach custom policy to Developers group
        if [[ "$group" == "Developers" ]]; then
            attach_policy_to_group "$group" "arn:aws:iam::$(aws_account_id "$profile"):policy/DeveloperCustomAccess" "$profile"
        fi
    done
    
    log "✅ All IAM groups created and configured successfully"
    echo
    log "Available groups:"
    for group in "${!group_policies[@]}"; do
        echo "  - $group"
    done
}

main "$@"