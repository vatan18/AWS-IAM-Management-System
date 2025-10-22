#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }
timestamp() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }

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

create_user_if_not_exists() {
    local user="$1" profile="$2"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    if $aws_cmd iam get-user --user-name "$user" &> /dev/null; then
        log "User '$user' already exists"
    else
        timestamp "Creating user '$user'"
        $aws_cmd iam create-user --user-name "$user"
        timestamp "User '$user' created successfully"
    fi
}

add_user_to_group() {
    local user="$1" group="$2" profile="$3"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    timestamp "Adding user '$user' to group '$group'"
    $aws_cmd iam add-user-to-group --user-name "$user" --group-name "$group"
}

create_access_keys() {
    local user="$1" profile="$2"
    local aws_cmd="aws"
    [[ -n "$profile" ]] && aws_cmd="aws --profile $profile"
    
    local account_id
    account_id=$(aws_account_id "$profile")
    local keyfile="$HOME/.aws/keys/${user}_${account_id}_accessKeys.csv"
    
    mkdir -p "$(dirname "$keyfile")"
    
    if [[ -f "$keyfile" ]]; then
        timestamp "Access key file already exists: $keyfile"
        local access_key_id secret_access_key
        access_key_id=$(tail -1 "$keyfile" | cut -d',' -f1)
        secret_access_key=$(tail -1 "$keyfile" | cut -d',' -f2)
        
        echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
        echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
        echo "export AWS_DEFAULT_REGION='${AWS_REGION:-us-east-1}'"
        return 0
    fi
    
    local existing_keys
    existing_keys=$($aws_cmd iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    
    if [[ $(echo "$existing_keys" | wc -w) -eq 2 ]]; then
        local oldest_key
        oldest_key=$($aws_cmd iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata | sort_by(@, &CreateDate)[0].AccessKeyId' --output text)
        timestamp "Deleting oldest access key: $oldest_key"
        $aws_cmd iam delete-access-key --user-name "$user" --access-key-id "$oldest_key"
    fi
    
    timestamp "Creating new access key for user '$user'"
    local key_output
    key_output=$($aws_cmd iam create-access-key --user-name "$user")
    
    local access_key_id secret_access_key
    access_key_id=$(echo "$key_output" | jq -r '.AccessKey.AccessKeyId')
    secret_access_key=$(echo "$key_output" | jq -r '.AccessKey.SecretAccessKey')
    
    echo "Access key ID,Secret access key" > "$keyfile"
    echo "$access_key_id,$secret_access_key" >> "$keyfile"
    timestamp "Access keys saved to: $keyfile"
    chmod 600 "$keyfile"
    
    echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
    echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
    echo "export AWS_DEFAULT_REGION='${AWS_REGION:-us-east-1}'"
}

usage() {
    cat << EOF
Usage: $0 --profile PROFILE USERNAME GROUP

Creates an IAM user and adds them to the specified group.

Available Groups:
  - Developers       (Read-only + ECR/EKS access)
  - S3-Readers       (S3 read-only access)
  - EKS-Deployers    (EKS cluster + ECR access)
  - Read-Only-Users  (Read-only all services)
  - Power-Users      (Power user access, no IAM)
  - Admins           (Full administrator access)

Examples:
  $0 --profile 81 john-developer Developers
  $0 --profile 81 jane-s3reader S3-Readers
  $0 --profile 81 bob-admin Admins

EOF
}

main() {
    local profile=""
    local user=""
    local group=""
    
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
                if [[ -z "$user" ]]; then
                    user="$1"
                elif [[ -z "$group" ]]; then
                    group="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$profile" || -z "$user" || -z "$group" ]]; then
        usage
        die "Missing required arguments"
    fi
    
    check_aws_cli "$profile"
    
    timestamp "Creating user '$user' in group '$group'"
    timestamp "AWS Account: $(aws_account_id "$profile")"
    
    create_user_if_not_exists "$user" "$profile"
    add_user_to_group "$user" "$group" "$profile"
    exports=$(create_access_keys "$user" "$profile")
    
    echo
    log "✅ User creation completed successfully"
    log "User: $user"
    log "Group: $group"
    log "Access Keys: $HOME/.aws/keys/${user}_$(aws_account_id "$profile")_accessKeys.csv"
    echo
    log "Use these credentials:"
    echo
    echo "$exports"
    echo
    log "Test credentials with:"
    echo "  export AWS_ACCESS_KEY_ID='...'"
    echo "  export AWS_SECRET_ACCESS_KEY='...'"
    echo "  aws sts get-caller-identity"
}

main "$@"