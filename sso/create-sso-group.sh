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
Create SSO Permission Set

Usage: 
  # Using AWS managed policy
  $0 --profile PROFILE --permission-set NAME --policy POLICY_NAME [--description "DESC"] [--session-duration DURATION]
  
  # Using custom policy (inline JSON)
  $0 --profile PROFILE --permission-set NAME --custom-policy 'POLICY_JSON' [--description "DESC"] [--session-duration DURATION]
  
  # Using custom policy (from file)
  $0 --profile PROFILE --permission-set NAME --custom-policy-file POLICY_FILE [--description "DESC"] [--session-duration DURATION]

Arguments:
  --profile PROFILE          AWS CLI profile
  --permission-set NAME      Name of the permission set
  --policy POLICY_NAME       AWS managed policy name
  --custom-policy JSON       Inline JSON policy
  --custom-policy-file FILE  Policy JSON file
  --description "DESC"       Description (optional)
  --session-duration DURATION Session duration (default: PT8H)
                            PT1H, PT4H, PT8H, PT12H

Examples:
  # Using AWS managed policy
  $0 --profile management-account --permission-set Developers --policy ReadOnlyAccess --description "Developers access" --session-duration PT12H
  
  # Using custom policy (inline)
  $0 --profile management-account --permission-set Logs-Viewers --custom-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:*"],"Resource":"*"}]}' --description "Logs access"
  
  # Using custom policy (file)
  $0 --profile management-account --permission-set Container-Devs --custom-policy-file ecr-policy.json --description "Container developers"

EOF
}

get_sso_instance() {
    local aws_cmd="$1" region="$2"
    $aws_cmd sso-admin list-instances --region "$region" --query "Instances[0].InstanceArn" --output text
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

create_permission_set() {
    local aws_cmd="$1" region="$2" instance_arn="$3" name="$4" description="$5" session_duration="$6"
    
    log "Creating permission set: $name"
    
    local permission_set_arn
    permission_set_arn=$($aws_cmd sso-admin create-permission-set \
        --instance-arn "$instance_arn" \
        --name "$name" \
        --description "$description" \
        --session-duration "$session_duration" \
        --region "$region" \
        --query "PermissionSet.PermissionSetArn" \
        --output text)
    
    echo "$permission_set_arn"
}

attach_managed_policy() {
    local aws_cmd="$1" region="$2" instance_arn="$3" permission_set_arn="$4" policy_name="$5"
    
    log "Attaching managed policy: $policy_name"
    $aws_cmd sso-admin attach-managed-policy-to-permission-set \
        --instance-arn "$instance_arn" \
        --permission-set-arn "$permission_set_arn" \
        --managed-policy-arn "arn:aws:iam::aws:policy/$policy_name" \
        --region "$region"
}

attach_custom_policy() {
    local aws_cmd="$1" region="$2" instance_arn="$3" permission_set_arn="$4" policy_content="$5"
    
    log "Attaching custom policy"
    
    # Create temporary policy file
    local policy_file="/tmp/sso-custom-policy-$$.json"
    echo "$policy_content" > "$policy_file"
    
    # Attach inline policy
    $aws_cmd sso-admin put-inline-policy-to-permission-set \
        --instance-arn "$instance_arn" \
        --permission-set-arn "$permission_set_arn" \
        --inline-policy "file://$policy_file" \
        --region "$region"
    
    rm -f "$policy_file"
}

main() {
    local profile="" permission_set="" policy="" custom_policy="" custom_policy_file="" description="" session_duration="PT8H" region="us-east-1"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --permission-set) permission_set="$2"; shift 2 ;;
            --policy) policy="$2"; shift 2 ;;
            --custom-policy) custom_policy="$2"; shift 2 ;;
            --custom-policy-file) custom_policy_file="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            --session-duration) session_duration="$2"; shift 2 ;;
            --region) region="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" || -z "$permission_set" ]] && { usage; exit 1; }
    
    # Validate policy options
    local policy_options=0
    [[ -n "$policy" ]] && ((policy_options++))
    [[ -n "$custom_policy" ]] && ((policy_options++))
    [[ -n "$custom_policy_file" ]] && ((policy_options++))
    
    [[ $policy_options -eq 0 ]] && { usage; die "Must specify one of: --policy, --custom-policy, or --custom-policy-file"; }
    [[ $policy_options -gt 1 ]] && { usage; die "Cannot specify multiple policy options"; }
    
    local aws_cmd="aws --profile $profile"
    
    # Get SSO instance
    log "Discovering SSO instance in region: $region"
    local instance_arn
    instance_arn=$(get_sso_instance "$aws_cmd" "$region")
    
    if [[ -z "$instance_arn" || "$instance_arn" == "None" ]]; then
        die "No SSO instance found in region $region. Please enable AWS SSO first."
    fi
    
    log "SSO Instance ARN: $instance_arn"
    log "Permission Set: $permission_set"
    log "Session Duration: $session_duration"
    [[ -n "$description" ]] && log "Description: $description"
    
    # Create permission set
    local permission_set_arn
    permission_set_arn=$(create_permission_set "$aws_cmd" "$region" "$instance_arn" "$permission_set" "$description" "$session_duration")
    
    # Attach policy based on the provided option
    if [[ -n "$policy" ]]; then
        # Using AWS managed policy
        attach_managed_policy "$aws_cmd" "$region" "$instance_arn" "$permission_set_arn" "$policy"
        
    elif [[ -n "$custom_policy" ]]; then
        # Using inline custom policy
        validate_json "$custom_policy"
        attach_custom_policy "$aws_cmd" "$region" "$instance_arn" "$permission_set_arn" "$custom_policy"
        
    elif [[ -n "$custom_policy_file" ]]; then
        # Using custom policy from file
        local policy_content
        policy_content=$(read_policy_file "$custom_policy_file")
        attach_custom_policy "$aws_cmd" "$region" "$instance_arn" "$permission_set_arn" "$policy_content"
    fi
    
    echo
    log "✅ SSO Permission Set created successfully"
    log "Permission Set: $permission_set"
    log "ARN: $permission_set_arn"
    log "Session Duration: $session_duration"
    echo
    log "Now assign users/groups to accounts:"
    echo "  ./assign-sso-user.sh --profile $profile --permission-set-arn $permission_set_arn --principal-type USER --principal-id USER_ID --account-id ACCOUNT_ID"
    echo "  ./assign-sso-user.sh --profile $profile --permission-set-arn $permission_set_arn --principal-type GROUP --principal-id GROUP_ID --account-id ACCOUNT_ID"
}

main "$@"