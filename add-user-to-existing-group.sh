#!/usr/bin/env bash
# add-user-to-existing-group.sh - Add user to any existing group

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[QUICK-ADD]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }
timestamp() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }

usage() {
    cat << EOF
⚡ QUICK USER ADDITION TO EXISTING GROUP

Usage: $0 --profile PROFILE USERNAME GROUP_NAME

Examples:
  $0 --profile 81 john-logsviewer Logs-Viewers
  $0 --profile 81 alice-costviewer Cost-Viewers
  $0 --profile 81 bob-backup Backup-Admins

Available Groups (check with): aws iam list-groups --profile PROFILE

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

aws_account_id() {
    local profile="${1:-}"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    $aws_cmd sts get-caller-identity --query "Account" --output text
}

check_group_exists() {
    local group_name="$1" profile="$2"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    if ! $aws_cmd iam get-group --group-name "$group_name" &>/dev/null; then
        die "Group '$group_name' does not exist. Create it first with create-emergency-group.sh"
    fi
}

main() {
    local profile="" username="" group_name=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *)
                if [[ -z "$username" ]]; then
                    username="$1"
                elif [[ -z "$group_name" ]]; then
                    group_name="$1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$profile" || -z "$username" || -z "$group_name" ]] && { usage; exit 1; }
    
    local aws_cmd="aws --profile $profile"
    
    # Validate inputs
    check_aws_cli "$profile"
    check_group_exists "$group_name" "$profile"
    
    timestamp "Quick-adding user '$username' to group '$group_name'"
    timestamp "AWS Account: $(aws_account_id "$profile")"
    
    # Create user if not exists
    if ! $aws_cmd iam get-user --user-name "$username" &>/dev/null; then
        timestamp "Creating user: $username"
        $aws_cmd iam create-user --user-name "$username"
    else
        timestamp "User '$username' already exists"
    fi
    
    # Add to group
    timestamp "Adding user '$username' to group '$group_name'"
    $aws_cmd iam add-user-to-group --user-name "$username" --group-name "$group_name"
    
    # Create access keys
    local account_id keyfile
    account_id=$(aws_account_id "$profile")
    keyfile="$HOME/.aws/keys/${username}_${account_id}_accessKeys.csv"
    
    mkdir -p "$(dirname "$keyfile")"
    
    # Check for existing keys
    if [[ -f "$keyfile" ]]; then
        timestamp "Access key file already exists: $keyfile"
        local access_key_id secret_access_key
        access_key_id=$(tail -1 "$keyfile" | cut -d',' -f1)
        secret_access_key=$(tail -1 "$keyfile" | cut -d',' -f2)
        
        echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
        echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
        echo "export AWS_DEFAULT_REGION='${AWS_REGION:-us-east-1}'"
    else
        timestamp "Creating access keys..."
        local key_output
        key_output=$($aws_cmd iam create-access-key --user-name "$username")
        
        local access_key_id secret_access_key
        access_key_id=$(echo "$key_output" | jq -r '.AccessKey.AccessKeyId')
        secret_access_key=$(echo "$key_output" | jq -r '.AccessKey.SecretAccessKey')
        
        echo "Access key ID,Secret access key" > "$keyfile"
        echo "$access_key_id,$secret_access_key" >> "$keyfile"
        chmod 600 "$keyfile"
        
        echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
        echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
        echo "export AWS_DEFAULT_REGION='${AWS_REGION:-us-east-1}'"
    fi
    
    echo
    log "✅ USER ADDED SUCCESSFULLY"
    log "User: $username"
    log "Group: $group_name"
    log "Keys: $keyfile"
    echo
    log "Test credentials with:"
    echo "  export AWS_ACCESS_KEY_ID='...'"
    echo "  export AWS_SECRET_ACCESS_KEY='...'"
    echo "  aws sts get-caller-identity"
}

main "$@"