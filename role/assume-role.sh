#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[ASSUME]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

usage() {
    cat << 'EOF'
Assume IAM Role for Temporary Access

Usage: 
  $0 --profile PROFILE --role-arn ROLE_ARN [--role-session-name NAME] [--duration DURATION] [--external-id ID] [--export] [--output FORMAT]

Arguments:
  --profile PROFILE          AWS CLI profile to use for assumption
  --role-arn ROLE_ARN        Role ARN to assume
  --role-session-name NAME   Session name (default: AssumeRoleSession)
  --duration DURATION        Duration in seconds (default: 3600, max: 43200)
  --external-id ID           External ID (for cross-account roles)
  --export                   Export credentials as environment variables
  --output FORMAT            Output format: env, json, credentials (default: env)

Examples:
  # Basic role assumption
  $0 --profile 81 --role-arn arn:aws:iam::123456789012:role/CrossAccount-Dev
  
  # With external ID and longer duration
  $0 --profile 81 --role-arn arn:aws:iam::123456789012:role/CrossAccount-Prod --external-id prod2024 --duration 7200 --export
  
  # Output as JSON
  $0 --profile 81 --role-arn arn:aws:iam::123456789012:role/ReadOnly-Role --output json

EOF
}

main() {
    local profile="" role_arn="" role_session_name="AssumeRoleSession" duration=3600 external_id="" export_creds=false output_format="env"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --role-arn) role_arn="$2"; shift 2 ;;
            --role-session-name) role_session_name="$2"; shift 2 ;;
            --duration) duration="$2"; shift 2 ;;
            --external-id) external_id="$2"; shift 2 ;;
            --export) export_creds=true; shift ;;
            --output) output_format="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" || -z "$role_arn" ]] && { usage; exit 1; }
    
    local aws_cmd="aws --profile $profile"
    
    log "Assuming role: $(basename "$role_arn")"
    log "Session: $role_session_name"
    log "Duration: $duration seconds"
    [[ -n "$external_id" ]] && log "External ID: $external_id"
    
    # Build assume-role command
    local assume_cmd=(
        $aws_cmd sts assume-role
        --role-arn "$role_arn"
        --role-session-name "$role_session_name"
        --duration-seconds "$duration"
    )
    
    [[ -n "$external_id" ]] && assume_cmd+=(--external-id "$external_id")
    
    # Assume role
    local credentials
    credentials=$("${assume_cmd[@]}")
    
    if [[ $? -ne 0 ]]; then
        die "Failed to assume role"
    fi
    
    local access_key_id secret_access_key session_token expiration assumed_role_arn
    access_key_id=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
    secret_access_key=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')
    session_token=$(echo "$credentials" | jq -r '.Credentials.SessionToken')
    expiration=$(echo "$credentials" | jq -r '.Credentials.Expiration')
    assumed_role_arn=$(echo "$credentials" | jq -r '.AssumedRoleUser.Arn')
    
    # Output based on format
    case "$output_format" in
        "env")
            if [[ "$export_creds" == true ]]; then
                log "📝 EXPORTING CREDENTIALS:"
                echo "export AWS_ACCESS_KEY_ID='$access_key_id'"
                echo "export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
                echo "export AWS_SESSION_TOKEN='$session_token'"
            else
                log "📝 CREDENTIALS:"
                echo "AWS_ACCESS_KEY_ID=$access_key_id"
                echo "AWS_SECRET_ACCESS_KEY=$secret_access_key"
                echo "AWS_SESSION_TOKEN=$session_token"
            fi
            ;;
        "json")
            echo "$credentials" | jq .
            return 0
            ;;
        "credentials")
            cat << EOF
[assumed-role]
aws_access_key_id = $access_key_id
aws_secret_access_key = $secret_access_key
aws_session_token = $session_token
region = us-east-1
EOF
            return 0
            ;;
    esac
    
    echo
    log "✅ ROLE ASSUMED SUCCESSFULLY"
    log "Assumed Role: $assumed_role_arn"
    log "Expiration: $expiration"
    echo
    log "Test the assumed role:"
    echo "  export AWS_ACCESS_KEY_ID='$access_key_id'"
    echo "  export AWS_SECRET_ACCESS_KEY='$secret_access_key'"
    echo "  export AWS_SESSION_TOKEN='$session_token'"
    echo "  aws sts get-caller-identity"
    echo
    log "⚠️  Temporary credentials expire at: $expiration"
}

main "$@"