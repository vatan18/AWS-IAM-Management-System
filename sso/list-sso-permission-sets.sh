#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat << 'EOF'
List SSO Permission Sets

Usage: $0 --profile PROFILE [--region REGION]

EOF
}

main() {
    local profile="" region="us-east-1"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile) profile="$2"; shift 2 ;;
            --region) region="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$profile" ]] && { usage; exit 1; }
    
    local aws_cmd="aws --profile $profile"
    local instance_arn
    
    instance_arn=$($aws_cmd sso-admin list-instances --region "$region" --query "Instances[0].InstanceArn" --output text)
    
    if [[ -z "$instance_arn" || "$instance_arn" == "None" ]]; then
        echo "No SSO instance found"
        exit 1
    fi
    
    echo "SSO Permission Sets:"
    echo "==================="
    
    $aws_cmd sso-admin list-permission-sets --instance-arn "$instance_arn" --region "$region" --query "PermissionSets[]" --output table
}

main "$@"