# AWS IAM Management System

Complete IAM, SSO, and Roles management system for AWS with comprehensive scripts for all identity and access management needs.

## 🏗️ Architecture Overview

```
AWS-IAM-Management-System/
├── 📁 iam/                    # IAM Users & Groups Management
│   ├── setup-iam-groups.sh
│   ├── create-user.sh
│   ├── create-group.sh
│   └── README.md
├── 📁 sso/                    # AWS SSO Management
│   ├── create-sso-group.sh
│   ├── assign-sso-user.sh
│   ├── list-sso-permission-sets.sh
│   └── README.md
├── 📁 role/                   # IAM Roles Management
│   ├── create-role.sh
│   ├── assume-role.sh
│   └── README.md
└── 📄 README.md              # This file
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- `jq` installed for JSON processing
- Bash shell environment

### Installation
```bash
# Make all scripts executable
chmod +x */*.sh

# Install jq if not available
sudo apt-get update && sudo apt-get install -y jq  # Ubuntu/Debian
```

## 📊 Scripts Overview

| Category | Script | Purpose |
|----------|---------|---------|
| **IAM** | `setup-iam-groups.sh` | Creates intial 25+ standard groups |
| **IAM** | `create-user.sh` | Creates users and assigns to groups |
| **IAM** | `create-group.sh` | Creates custom groups |
| **SSO** | `create-sso-group.sh` | Creates SSO permission sets |
| **SSO** | `assign-sso-user.sh` | Assigns users to accounts |
| **Roles** | `create-role.sh` | Creates various IAM roles |
| **Roles** | `assume-role.sh` | Assumes roles for temporary access |

## 🎯 Common Workflows

### Development Team Setup
```bash
# Setup IAM groups
./iam/setup-iam-groups.sh --profile 81

# Create developers
./iam/create-user.sh --profile 81 --username john.dev --group Developers
./iam/create-user.sh --profile 81 --username alice.senior --group Senior-Developers
```

### Cross-Account Access
```bash
# Create cross-account role
./role/create-role.sh --profile production --role-name CrossAccount-Dev --type cross-account --trust-account 123456789012 --policy ReadOnlyAccess

# Assume the role
./role/assume-role.sh --profile dev-account --role-arn arn:aws:iam::123456789012:role/CrossAccount-Dev --export
```

### Enterprise SSO Setup
```bash
# Create SSO permission sets
./sso/create-sso-group.sh --profile management-account --permission-set Developers --policy ReadOnlyAccess

# Assign teams to accounts
./sso/assign-sso-user.sh --profile management-account --permission-set Developers --principal-type GROUP --principal-id dev-group-id --account-id 123456789012
```

## 🔒 Security Best Practices

- **Principle of Least Privilege**: Grant minimum required permissions
- **Regular Access Reviews**: Review and clean up unused access
- **MFA Enforcement**: Enable MFA for all users
- **Credential Management**: Access keys stored securely in `~/.aws/keys/`
- **Session Management**: Appropriate session durations for different roles

## 💡 Typical Use Cases

### Single Account Management
Use the `iam/` scripts for managing users and groups within a single AWS account.

### Multi-Account Enterprise
Use the `sso/` scripts for centralized identity management across multiple accounts.

### Service & Cross-Account Access
Use the `role/` scripts for service roles, cross-account access, and temporary credentials.

## 🆘 Getting Help

Each folder contains detailed documentation with examples:
- [IAM Documentation](iam/README.md)
- [SSO Documentation](sso/README.md) 
- [Roles Documentation](role/README.md)

For specific use cases and detailed examples, refer to the individual folder README files.