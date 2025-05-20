# 3x-ui VPN Service Scripts

This directory contains utility scripts for managing, securing, and maintaining your 3x-ui VPN service.

## Security Scripts

### Security Check (`security_check.sh`)

A comprehensive security audit and hardening tool for your 3x-ui VPN service.

```bash
npm run security:check   # Check security configuration
npm run security:fix     # Apply security fixes and restart service
```

Features:
- Docker Compose security configuration check
- Environment variable verification
- Certificate security assessment
- Database & file permission hardening
- XRay configuration security audit
- System hardening recommendations

### Certificate Management (`renew_certificates.sh`)

Automatically validates and manages SSL certificates for your VPN service.

```bash
npm run cert:check
```

Features:
- Certificate expiration monitoring
- Self-signed certificate generation if needed
- Certificate and private key verification
- Proper permission enforcement
- Automatic service restart when certificates change

### Docker Configuration Checker (`check_docker_config.sh`)

Validates the docker-compose.yml configuration for 3x-ui VPN service.

```bash
npm run docker:check
```

Features:
- Validates docker-compose.yml syntax
- Checks for required services and port mappings
- Validates admin credentials configuration
- Checks for JWT_SECRET configuration
- Identifies potential security issues
- Ensures proper reverse proxy setup

### JWT Secret Manager (`update_jwt_secret.sh`)

Generates and updates the JWT secret for secure authentication.

```bash
npm run jwt:update            # Interactive mode
npm run jwt:update:auto       # Automatic mode - updates all config files
npm run jwt:update:env        # Only update .env file
npm run jwt:update:compose    # Only update docker-compose.yml file
```

Features:
- Generates cryptographically secure random JWT secrets
- Updates configuration in .env file and/or docker-compose.yml
- Creates backups before making changes
- Supports both interactive and non-interactive modes
- Validates changes after updating

## Backup Scripts

### Automated Backup (`backup.sh`)

Performs a complete backup of your 3x-ui VPN configuration and data.

```bash
npm run backup
```

Features:
- SQLite database backup
- Certificate backup
- Configuration file backup
- Consolidated full backup archive
- Backup integrity verification
- Automatic retention management (7-day default)
- Detailed backup report

## Development Scripts

### Commit Helper (`commit.sh`)

Automates the commit process according to project standards.

```bash
npm run commit "your commit message" "Type"
```

Examples:
```bash
npm run commit "add certificate renewal script" "Feat"
npm run commit "fix database permissions" "Fix"
```

Supported types:
- `Feat`: New features
- `Fix`: Bug fixes
- `Docs`: Documentation changes
- `Refactor`: Code refactoring
- `Style`: Formatting changes
- `Test`: Testing improvements
- `Chore`: Maintenance tasks

## Utility Functions

### Utils Library (`utils.sh`)

Common utilities used by all scripts.

Features:
- Colored logging functions
- Command execution wrappers
- Environment detection
- File and permission management
- Service status monitoring
- Interactive user prompts

## Usage Recommendations

1. Run `security:check` regularly to ensure your system remains secure
2. Schedule regular backups using `backup.sh` (recommended daily)
3. Set up a cron job to check certificates at least weekly
4. Always use the commit script to maintain a consistent git history

## Integration with CI/CD

These scripts are designed to work both locally and in GitHub Actions workflows.
See `.github/workflows/3x-ui-workflow.yml` for integration examples. 