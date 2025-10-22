#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
section() { echo -e "${BLUE}==>${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

usage() {
    cat << 'EOF'
Setup Comprehensive IAM Groups for DevOps & Administration

Usage: $0 --profile PROFILE

Creates standard IAM groups covering all DevOps and administrative needs:
- Administration & Access
- Development & CI/CD
- Infrastructure & Operations  
- Security & Compliance
- Database & Storage
- Monitoring & Support

EOF
}

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
    local group_name="$1" profile="$2"
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
    local group_name="$1" policy_arn="$2" profile="$3"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    log "Attaching policy: $(basename "$policy_arn")"
    $aws_cmd iam attach-group-policy --group-name "$group_name" --policy-arn "$policy_arn"
}

aws_account_id() {
    local profile="${1:-}"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    $aws_cmd sts get-caller-identity --query "Account" --output text
}

main() {
    local profile=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" ]] && { usage; exit 1; }
    
    check_aws_cli "$profile"
    local account_id=$(aws_account_id "$profile")
    
    section "Setting up IAM Groups for AWS Account: $account_id"
    echo
    
    # Comprehensive groups for DevOps/Administrator needs
    declare -A group_policies=(
        # ==================== ADMINISTRATION & ACCESS ====================
        ["Super-Admins"]="AdministratorAccess"
        ["Billing-Admins"]="AWSBillingReadOnlyAccess"
        ["IAM-Admins"]="IAMFullAccess"
        
        # ==================== DEVELOPMENT & CI/CD ====================
        ["Developers"]="ReadOnlyAccess"
        ["Senior-Developers"]="PowerUserAccess"
        ["CI-CD-Engineers"]="AWSCodePipeline_FullAccess"
        ["Container-Engineers"]="AmazonEC2ContainerRegistryPowerUser"
        ["Lambda-Developers"]="AWSLambda_FullAccess"
        
        # ==================== INFRASTRUCTURE & OPERATIONS ====================
        ["Network-Admins"]="AmazonVPCFullAccess"
        ["EC2-Admins"]="AmazonEC2FullAccess"
        ["EKS-Admins"]="AmazonEKSClusterPolicy"
        ["EKS-Developers"]="AmazonEKSWorkerNodePolicy"
        ["LoadBalancer-Admins"]="ElasticLoadBalancingFullAccess"
        ["AutoScaling-Admins"]="AutoScalingFullAccess"
        
        # ==================== SECURITY & COMPLIANCE ====================
        ["Security-Admins"]="SecurityAudit"
        ["Security-Auditors"]="AWSConfigUserAccess"
        ["Compliance-Auditors"]="AWSSecurityHubReadOnlyAccess"
        ["KMS-Admins"]="AWSKeyManagementServicePowerUser"
        
        # ==================== DATABASE & STORAGE ====================
        ["Database-Admins"]="AmazonRDSFullAccess"
        ["DynamoDB-Admins"]="AmazonDynamoDBFullAccess"
        ["S3-Admins"]="AmazonS3FullAccess"
        ["EFS-Admins"]="AmazonElasticFileSystemFullAccess"
        
        # ==================== MONITORING & SUPPORT ====================
        ["Monitoring-Admins"]="CloudWatchFullAccess"
        ["Logs-Viewers"]="CloudWatchLogsReadOnlyAccess"
        ["Support-Engineers"]="AWSSupportAccess"
        ["Cost-Optimizers"]="AWSCostExplorerReadOnlyAccess"
        
        # ==================== SPECIALIZED ROLES ====================
        ["Data-Engineers"]="AmazonS3FullAccess"
        ["ML-Engineers"]="AmazonSageMakerFullAccess"
        ["Backup-Admins"]="AWSBackupFullAccess"
        ["Disaster-Recovery"]="AWSBackupFullAccess"
    )
    
    section "ADMINISTRATION & ACCESS"
    create_group_if_not_exists "Super-Admins" "$profile"
    attach_policy_to_group "Super-Admins" "arn:aws:iam::aws:policy/AdministratorAccess" "$profile"
    
    create_group_if_not_exists "Billing-Admins" "$profile"
    attach_policy_to_group "Billing-Admins" "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess" "$profile"
    
    create_group_if_not_exists "IAM-Admins" "$profile"
    attach_policy_to_group "IAM-Admins" "arn:aws:iam::aws:policy/IAMFullAccess" "$profile"
    
    section "DEVELOPMENT & CI/CD"
    create_group_if_not_exists "Developers" "$profile"
    attach_policy_to_group "Developers" "arn:aws:iam::aws:policy/ReadOnlyAccess" "$profile"
    
    create_group_if_not_exists "Senior-Developers" "$profile"
    attach_policy_to_group "Senior-Developers" "arn:aws:iam::aws:policy/PowerUserAccess" "$profile"
    
    create_group_if_not_exists "CI-CD-Engineers" "$profile"
    attach_policy_to_group "CI-CD-Engineers" "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess" "$profile"
    
    create_group_if_not_exists "Container-Engineers" "$profile"
    attach_policy_to_group "Container-Engineers" "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser" "$profile"
    
    create_group_if_not_exists "Lambda-Developers" "$profile"
    attach_policy_to_group "Lambda-Developers" "arn:aws:iam::aws:policy/AWSLambda_FullAccess" "$profile"
    
    section "INFRASTRUCTURE & OPERATIONS"
    create_group_if_not_exists "Network-Admins" "$profile"
    attach_policy_to_group "Network-Admins" "arn:aws:iam::aws:policy/AmazonVPCFullAccess" "$profile"
    
    create_group_if_not_exists "EC2-Admins" "$profile"
    attach_policy_to_group "EC2-Admins" "arn:aws:iam::aws:policy/AmazonEC2FullAccess" "$profile"
    
    create_group_if_not_exists "EKS-Admins" "$profile"
    attach_policy_to_group "EKS-Admins" "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" "$profile"
    
    create_group_if_not_exists "EKS-Developers" "$profile"
    attach_policy_to_group "EKS-Developers" "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" "$profile"
    
    create_group_if_not_exists "LoadBalancer-Admins" "$profile"
    attach_policy_to_group "LoadBalancer-Admins" "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess" "$profile"
    
    create_group_if_not_exists "AutoScaling-Admins" "$profile"
    attach_policy_to_group "AutoScaling-Admins" "arn:aws:iam::aws:policy/AutoScalingFullAccess" "$profile"
    
    section "SECURITY & COMPLIANCE"
    create_group_if_not_exists "Security-Admins" "$profile"
    attach_policy_to_group "Security-Admins" "arn:aws:iam::aws:policy/SecurityAudit" "$profile"
    
    create_group_if_not_exists "Security-Auditors" "$profile"
    attach_policy_to_group "Security-Auditors" "arn:aws:iam::aws:policy/AWSConfigUserAccess" "$profile"
    
    create_group_if_not_exists "Compliance-Auditors" "$profile"
    attach_policy_to_group "Compliance-Auditors" "arn:aws:iam::aws:policy/AWSSecurityHubReadOnlyAccess" "$profile"
    
    create_group_if_not_exists "KMS-Admins" "$profile"
    attach_policy_to_group "KMS-Admins" "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser" "$profile"
    
    section "DATABASE & STORAGE"
    create_group_if_not_exists "Database-Admins" "$profile"
    attach_policy_to_group "Database-Admins" "arn:aws:iam::aws:policy/AmazonRDSFullAccess" "$profile"
    
    create_group_if_not_exists "DynamoDB-Admins" "$profile"
    attach_policy_to_group "DynamoDB-Admins" "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" "$profile"
    
    create_group_if_not_exists "S3-Admins" "$profile"
    attach_policy_to_group "S3-Admins" "arn:aws:iam::aws:policy/AmazonS3FullAccess" "$profile"
    
    create_group_if_not_exists "EFS-Admins" "$profile"
    attach_policy_to_group "EFS-Admins" "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess" "$profile"
    
    section "MONITORING & SUPPORT"
    create_group_if_not_exists "Monitoring-Admins" "$profile"
    attach_policy_to_group "Monitoring-Admins" "arn:aws:iam::aws:policy/CloudWatchFullAccess" "$profile"
    
    create_group_if_not_exists "Logs-Viewers" "$profile"
    attach_policy_to_group "Logs-Viewers" "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess" "$profile"
    
    create_group_if_not_exists "Support-Engineers" "$profile"
    attach_policy_to_group "Support-Engineers" "arn:aws:iam::aws:policy/AWSSupportAccess" "$profile"
    
    create_group_if_not_exists "Cost-Optimizers" "$profile"
    attach_policy_to_group "Cost-Optimizers" "arn:aws:iam::aws:policy/AWSCostExplorerReadOnlyAccess" "$profile"
    
    section "SPECIALIZED ROLES"
    create_group_if_not_exists "Data-Engineers" "$profile"
    attach_policy_to_group "Data-Engineers" "arn:aws:iam::aws:policy/AmazonS3FullAccess" "$profile"
    
    create_group_if_not_exists "ML-Engineers" "$profile"
    attach_policy_to_group "ML-Engineers" "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess" "$profile"
    
    create_group_if_not_exists "Backup-Admins" "$profile"
    attach_policy_to_group "Backup-Admins" "arn:aws:iam::aws:policy/AWSBackupFullAccess" "$profile"
    
    create_group_if_not_exists "Disaster-Recovery" "$profile"
    attach_policy_to_group "Disaster-Recovery" "arn:aws:iam::aws:policy/AWSBackupFullAccess" "$profile"
    
    echo
    section "✅ ALL IAM GROUPS CREATED SUCCESSFULLY"
    echo
    log "Total groups created: ${#group_policies[@]}"
    echo
    section "📋 GROUPS SUMMARY"
    echo
    log "ADMINISTRATION & ACCESS:"
    echo "  • Super-Admins (AdministratorAccess)"
    echo "  • Billing-Admins (AWSBillingReadOnlyAccess)" 
    echo "  • IAM-Admins (IAMFullAccess)"
    echo
    log "DEVELOPMENT & CI/CD:"
    echo "  • Developers (ReadOnlyAccess)"
    echo "  • Senior-Developers (PowerUserAccess)"
    echo "  • CI-CD-Engineers (AWSCodePipeline_FullAccess)"
    echo "  • Container-Engineers (AmazonEC2ContainerRegistryPowerUser)"
    echo "  • Lambda-Developers (AWSLambda_FullAccess)"
    echo
    log "INFRASTRUCTURE & OPERATIONS:"
    echo "  • Network-Admins (AmazonVPCFullAccess)"
    echo "  • EC2-Admins (AmazonEC2FullAccess)"
    echo "  • EKS-Admins (AmazonEKSClusterPolicy)"
    echo "  • EKS-Developers (AmazonEKSWorkerNodePolicy)"
    echo "  • LoadBalancer-Admins (ElasticLoadBalancingFullAccess)"
    echo "  • AutoScaling-Admins (AutoScalingFullAccess)"
    echo
    log "SECURITY & COMPLIANCE:"
    echo "  • Security-Admins (SecurityAudit)"
    echo "  • Security-Auditors (AWSConfigUserAccess)"
    echo "  • Compliance-Auditors (AWSSecurityHubReadOnlyAccess)"
    echo "  • KMS-Admins (AWSKeyManagementServicePowerUser)"
    echo
    log "DATABASE & STORAGE:"
    echo "  • Database-Admins (AmazonRDSFullAccess)"
    echo "  • DynamoDB-Admins (AmazonDynamoDBFullAccess)"
    echo "  • S3-Admins (AmazonS3FullAccess)"
    echo "  • EFS-Admins (AmazonElasticFileSystemFullAccess)"
    echo
    log "MONITORING & SUPPORT:"
    echo "  • Monitoring-Admins (CloudWatchFullAccess)"
    echo "  • Logs-Viewers (CloudWatchLogsReadOnlyAccess)"
    echo "  • Support-Engineers (AWSSupportAccess)"
    echo "  • Cost-Optimizers (AWSCostExplorerReadOnlyAccess)"
    echo
    log "SPECIALIZED ROLES:"
    echo "  • Data-Engineers (AmazonS3FullAccess)"
    echo "  • ML-Engineers (AmazonSageMakerFullAccess)"
    echo "  • Backup-Admins (AWSBackupFullAccess)"
    echo "  • Disaster-Recovery (AWSBackupFullAccess)"
    echo
    section "🎯 NEXT STEPS"
    echo "Create users and assign to groups:"
    echo "  ./create-user.sh --profile $profile --username john.doe --group Developers"
    echo "  ./create-user.sh --profile $profile --username alice.smith --group Senior-Developers"
    echo
    log "Create additional custom groups if needed:"
    echo "  ./create-group.sh --profile $profile --group-name Custom-Group --policy PolicyName"
}

main "$@"