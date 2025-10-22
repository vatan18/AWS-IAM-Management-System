#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[SSO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

usage() {
    cat << 'EOF'
Assign User/Group to SSO Permission Set

Usage: 
  $0 --profile PROFILE --permission-set-arn ARN --principal-type [USER|GROUP] --principal-id ID --account-id ACCOUNT_ID [--region REGION]

  OR using permission set name:
  $0 --profile PROFILE --permission-set NAME --principal-type [USER|GROUP] --principal-id ID --account-id ACCOUNT_ID [--region REGION]

Arguments:
  --profile PROFILE          AWS CLI profile (management account)
  --permission-set-arn ARN   Permission set ARN
  --permission-set NAME      Permission set name (alternative to ARN)
  --principal-type TYPE      USER or GROUP
  --principal-id ID          User/Group ID from Identity Store
  --account-id ID            Target AWS account ID
  --region REGION            AWS region (default: us-east-1)

Examples:
  # Using permission set ARN
  $0 --profile management-account --permission-set-arn arn:aws:sso:::permissionSet/ssoins-123456/ps-789012 --principal-type USER --principal-id a1b2c3d4-5678-90ab-cdef-123456789012 --account-id 123456789012
  
  # Using permission set name
  $0 --profile management-account --permission-set Developers --principal-type GROUP --principal-id g1h2i3j4-5678-90ab-cdef-123456789012 --account-id 123456789012
  
  # Assign to multiple accounts
  $0 --profile management-account --permission-set ReadOnly --principal-type USER --principal-id u1v2w3x4-5678-90ab-cdef-123456789012 --account-id 111222333444
  $0 --profile management-account --permission-set ReadOnly --principal-type USER --principal-id u1v2w3x4-5678-90ab-cdef-123456789012 --account-id 555666777888

EOF
}

get_sso_instance() {
    local aws_cmd="$1" region="$2"
    $aws_cmd sso-admin list-instances --region "$region" --query "Instances[0].InstanceArn" --output text
}

get_permission_set_arn() {
    local aws_cmd="$1" region="$2" instance_arn="$3" permission_set_name="$4"
    $aws_cmd sso-admin list-permission-sets --instance-arn "$instance_arn" --region "$region" --query "PermissionSets[?contains(@, '$permission_set_name')]" --output text
}

main() {
    local profile="" permission_set_arn="" permission_set="" principal_type="" principal_id="" account_id="" region="us-east-1"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --permission-set-arn) permission_set_arn="$2"; shift 2 ;;
            --permission-set) permission_set="$2"; shift 2 ;;
            --principal-type) principal_type="$2"; shift 2 ;;
            --principal-id) principal_id="$2"; shift 2 ;;
            --account-id) account_id="$2"; shift 2 ;;
            --region) region="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" || -z "$principal_type" || -z "$principal_id" || -z "$account_id" ]] && { usage; exit 1; }
    [[ -z "$permission_set_arn" && -z "$permission_set" ]] && { usage; die "Must specify either --permission-set-arn or --permission-set"; }
    
    local aws_cmd="aws --profile $profile"
    
    # Get SSO instance
    local instance_arn
    instance_arn=$(get_sso_instance "$aws_cmd" "$region")
    
    if [[ -z "$instance_arn" || "$instance_arn" == "None" ]]; then
        die "No SSO instance found in region $region"
    fi
    
    # Resolve permission set ARN if name was provided
    if [[ -n "$permission_set" && -z "$permission_set_arn" ]]; then
        log "Looking up permission set: $permission_set"
        permission_set_arn=$(get_permission_set_arn "$aws_cmd" "$region" "$instance_arn" "$permission_set")
        
        if [[ -z "$permission_set_arn" ]]; then
            die "Permission set not found: $permission_set"
        fi
    fi
    
    log "Assigning $principal_type to AWS Account"
    log "Principal: $principal_type $principal_id"
    log "Permission Set: $(basename "$permission_set_arn")"
    log "Target Account: $account_id"
    log "SSO Instance: $(basename "$instance_arn")"
    
    # Create account assignment
    $aws_cmd sso-admin create-account-assignment \
        --instance-arn "$instance_arn" \
        --permission-set-arn "$permission_set_arn" \
        --principal-type "$principal_type" \
        --principal-id "$principal_id" \
        --target-type "AWS_ACCOUNT" \
        --target-id "$account_id" \
        --region "$region"
    
    echo
    log "✅ SSO Assignment created successfully"
    log "Assignment will be provisioned within a few minutes"
    echo
    log "To verify assignment:"
    echo "  aws sso-admin list-account-assignments --instance-arn $instance_arn --account-id $account_id --permission-set-arn $permission_set_arn --region $region --profile $profile"
}

main "$@"