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
Create IAM User

Usage: $0 --profile PROFILE --username USERNAME --group GROUP

Examples:
  $0 --profile 81 --username john.doe --group Developers
  $0 --profile 81 --username alice.smith --group Senior-Developers
  $0 --profile 81 --username bob.admin --group Super-Admins

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

create_user_if_not_exists() {
    local user="$1" profile="$2"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    if $aws_cmd iam get-user --user-name "$user" &> /dev/null; then
        log "User '$user' already exists"
    else
        log "Creating user: $user"
        $aws_cmd iam create-user --user-name "$user"
    fi
}

add_user_to_group() {
    local user="$1" group="$2" profile="$3"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    log "Adding user '$user' to group '$group'"
    $aws_cmd iam add-user-to-group --user-name "$user" --group-name "$group"
}

create_access_keys() {
    local user="$1" profile="$2"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    local account_id
    account_id=$($aws_cmd sts get-caller-identity --query "Account" --output text)
    local keyfile="$HOME/.aws/keys/${user}_${account_id}_accessKeys.csv"
    
    mkdir -p "$(dirname "$keyfile")"
    
    if [[ -f "$keyfile" ]]; then
        log "Access key file already exists: $keyfile"
        local access_key_id secret_access_key
        access_key_id=$(tail -1 "$keyfile" | cut -d',' -f1)
        secret_access_key=$(tail -1 "$keyfile" | cut -d',' -f2)
        
        echo
        log "Use existing credentials:"
        echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
        echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
        echo "export AWS_DEFAULT_REGION='us-east-1'"
        return 0
    fi
    
    log "Creating access keys for user '$user'"
    local key_output
    key_output=$($aws_cmd iam create-access-key --user-name "$user")
    
    local access_key_id secret_access_key
    access_key_id=$(echo "$key_output" | jq -r '.AccessKey.AccessKeyId')
    secret_access_key=$(echo "$key_output" | jq -r '.AccessKey.SecretAccessKey')
    
    echo "Access key ID,Secret access key" > "$keyfile"
    echo "$access_key_id,$secret_access_key" >> "$keyfile"
    chmod 600 "$keyfile"
    
    log "Access keys saved to: $keyfile"
    
    echo
    log "Use these credentials:"
    echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
    echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
    echo "export AWS_DEFAULT_REGION='us-east-1'"
}

main() {
    local profile="" username="" group=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --username) username="$2"; shift 2 ;;
            --group) group="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" || -z "$username" || -z "$group" ]] && { usage; exit 1; }
    
    check_aws_cli "$profile"
    
    log "Creating user: $username"
    log "Group: $group"
    log "Profile: $profile"
    
    create_user_if_not_exists "$username" "$profile"
    add_user_to_group "$username" "$group" "$profile"
    create_access_keys "$username" "$profile"
    
    echo
    log "✅ User creation completed successfully"
    log ""
    log "Test credentials with:"
    echo "  export AWS_ACCESS_KEY_ID='...'"
    echo "  export AWS_SECRET_ACCESS_KEY='...'"
    echo "  aws sts get-caller-identity"
}

main "$@"