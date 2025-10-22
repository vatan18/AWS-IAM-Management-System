#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

usage() {
    cat << 'EOF'
Create IAM Group

Usage: 
  # Using AWS managed policy
  $0 --profile PROFILE --group-name GROUP_NAME --policy POLICY_NAME [--description "DESC"]
  
  # Using custom policy (inline JSON)
  $0 --profile PROFILE --group-name GROUP_NAME --custom-policy 'POLICY_JSON' [--description "DESC"]
  
  # Using custom policy (from file)
  $0 --profile PROFILE --group-name GROUP_NAME --custom-policy-file POLICY_FILE [--description "DESC"]

POLICY_NAME can be:
  - AWS managed policy name (e.g., ReadOnlyAccess, AmazonS3ReadOnlyAccess)
  - Common policies: ReadOnlyAccess, PowerUserAccess, AdministratorAccess, 
    AmazonS3ReadOnlyAccess, AmazonEC2FullAccess, AmazonRDSFullAccess, etc.

Examples:
  # Using AWS managed policy
  $0 --profile 81 --group-name Developers --policy ReadOnlyAccess --description "Developers group"
  
  # Using custom policy (inline JSON)
  $0 --profile 81 --group-name Logs-Viewers --custom-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:*"],"Resource":"*"}]}' --description "Logs access group"

  # Using custom policy (from file)
  $0 --profile 81 --group-name Special-Access --custom-policy-file my-policy.json --description "Special access group"

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

main() {
    local profile="" group_name="" policy="" custom_policy="" custom_policy_file="" description=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --group-name) group_name="$2"; shift 2 ;;
            --policy) policy="$2"; shift 2 ;;
            --custom-policy) custom_policy="$2"; shift 2 ;;
            --custom-policy-file) custom_policy_file="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" || -z "$group_name" ]] && { usage; exit 1; }
    
    # Validate policy options
    local policy_options=0
    [[ -n "$policy" ]] && ((policy_options++))
    [[ -n "$custom_policy" ]] && ((policy_options++))
    [[ -n "$custom_policy_file" ]] && ((policy_options++))
    
    [[ $policy_options -eq 0 ]] && { usage; die "Must specify one of: --policy, --custom-policy, or --custom-policy-file"; }
    [[ $policy_options -gt 1 ]] && { usage; die "Cannot specify multiple policy options"; }
    
    local aws_cmd="aws --profile $profile"
    
    log "Creating group: $group_name"
    [[ -n "$description" ]] && log "Description: $description"
    
    # Check if group already exists
    if $aws_cmd iam get-group --group-name "$group_name" &>/dev/null; then
        log "Group '$group_name' already exists"
    else
        # Create group
        $aws_cmd iam create-group --group-name "$group_name"
    fi
    
    # Attach policy based on the provided option
    if [[ -n "$policy" ]]; then
        # Using AWS managed policy
        log "Attaching AWS managed policy: $policy"
        $aws_cmd iam attach-group-policy \
            --group-name "$group_name" \
            --policy-arn "arn:aws:iam::aws:policy/$policy"
            
    elif [[ -n "$custom_policy" ]]; then
        # Using inline custom policy
        log "Attaching custom policy (inline)"
        validate_json "$custom_policy"
        echo "$custom_policy" > /tmp/custom-policy.json
        
        $aws_cmd iam put-group-policy \
            --group-name "$group_name" \
            --policy-name "${group_name}Policy" \
            --policy-document file:///tmp/custom-policy.json
        
        rm -f /tmp/custom-policy.json
        
    elif [[ -n "$custom_policy_file" ]]; then
        # Using custom policy from file
        log "Attaching custom policy from file: $custom_policy_file"
        local policy_content
        policy_content=$(read_policy_file "$custom_policy_file")
        
        echo "$policy_content" > /tmp/custom-policy-file.json
        
        $aws_cmd iam put-group-policy \
            --group-name "$group_name" \
            --policy-name "${group_name}Policy" \
            --policy-document file:///tmp/custom-policy-file.json
        
        rm -f /tmp/custom-policy-file.json
    fi
    
    log "✅ Group created successfully: $group_name"
    log ""
    log "Now create users for this group:"
    echo "  ./create-user.sh --profile $profile --username USERNAME --group $group_name"
}

main "$@"