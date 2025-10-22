#!/usr/bin/env bash
# create-emergency-group.sh - For urgent custom group creation

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[EMERGENCY]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

usage() {
    cat << EOF
🚨 EMERGENCY GROUP CREATION - No script modification needed!

Usage: $0 --profile PROFILE GROUP_NAME 'POLICY_JSON' "DESCRIPTION"

Examples:
  $0 --profile 81 Logs-Viewers '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:Describe*","logs:Get*"],"Resource":"*"}]}' "CloudWatch Logs access"

  $0 --profile 81 Backup-Admins '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["backup:*"],"Resource":"*"}]}' "AWS Backup full access"

  $0 --profile 81 Cost-Viewers '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["ce:*","budgets:ViewBudget"],"Resource":"*"}]}' "Cost Explorer access"

EOF
}

main() {
    local profile="" group_name="" policy_json="" description=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                profile="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [[ -z "$group_name" ]]; then
                    group_name="$1"
                elif [[ -z "$policy_json" ]]; then
                    policy_json="$1"
                elif [[ -z "$description" ]]; then
                    description="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$profile" || -z "$group_name" || -z "$policy_json" || -z "$description" ]]; then
        usage
        die "Missing required arguments"
    fi
    
    local aws_cmd="aws --profile $profile"
    
    # Validate AWS access
    if ! $aws_cmd sts get-caller-identity &>/dev/null; then
        die "AWS CLI not working with profile: $profile"
    fi
    
    local account_id
    account_id=$($aws_cmd sts get-caller-identity --query "Account" --output text)
    local policy_name="${group_name}CustomPolicy"
    
    log "Creating emergency group: $group_name"
    log "Account: $account_id"
    log "Description: $description"
    
    # Create group
    if ! $aws_cmd iam get-group --group-name "$group_name" &>/dev/null; then
        log "Creating group: $group_name"
        $aws_cmd iam create-group --group-name "$group_name"
    else
        log "Group already exists: $group_name"
    fi
    
    # Create custom policy
    echo "$policy_json" > /tmp/emergency-policy.json
    
    # Validate JSON syntax
    if ! jq empty /tmp/emergency-policy.json 2>/dev/null; then
        rm -f /tmp/emergency-policy.json
        die "Invalid JSON policy syntax"
    fi
    
    log "Creating custom policy: $policy_name"
    $aws_cmd iam create-policy \
        --policy-name "$policy_name" \
        --policy-document file:///tmp/emergency-policy.json \
        --description "$description"
    
    # Attach policy to group
    local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"
    log "Attaching policy to group"
    $aws_cmd iam attach-group-policy \
        --group-name "$group_name" \
        --policy-arn "$policy_arn"
    
    # Cleanup
    rm -f /tmp/emergency-policy.json
    
    echo
    log "✅ EMERGENCY GROUP CREATED SUCCESSFULLY"
    log "Group: $group_name"
    log "Policy: $policy_name"
    log "Policy ARN: $policy_arn"
    echo
    log "🎯 NOW CREATE USERS FOR THIS GROUP:"
    echo "  ./add-user-to-existing-group.sh --profile $profile username '$group_name'"
    echo
    log "📋 POLICY DETAILS:"
    echo "$policy_json" | jq .
}

main "$@"