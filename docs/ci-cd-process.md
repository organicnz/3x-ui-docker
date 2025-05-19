# CI/CD Process for 3x-ui VPN Service

This document outlines the continuous integration and continuous deployment (CI/CD) process for the 3x-ui VPN service.

## Table of Contents

- [Overview](#overview)
- [Workflow Structure](#workflow-structure)
- [Environment Variables and Secrets](#environment-variables-and-secrets)
- [Deployment Process](#deployment-process)
- [Backup Process](#backup-process)
- [Local Testing](#local-testing)
- [Troubleshooting](#troubleshooting)

## Overview

The CI/CD process automates the deployment, backup, and management of the 3x-ui VPN service using GitHub Actions. The workflow is designed to be flexible, allowing for various operations to be performed based on triggers or manual dispatch.

### Key Features

- **Automated Deployment**: Push changes to the main branch to trigger deployment
- **Scheduled Backups**: Daily automated backups of the database
- **Manual Operations**: Trigger specific operations manually via the GitHub Actions interface
- **Comprehensive Logging**: Detailed logs for all operations
- **Local Testing**: Test workflows locally before pushing to GitHub

## Workflow Structure

The workflow is organized into distinct jobs, each responsible for a specific aspect of the CI/CD process:

1. **Debug Info** (🐛): Displays information about the workflow trigger
2. **Validation** (🔍): Validates configuration files before proceeding
3. **Setup** (🚀): Configures the server environment if needed
4. **Deployment** (🚢): Deploys the 3x-ui service to the server
5. **Verification** (✅): Verifies that the deployment was successful
6. **Backup** (💾): Creates and archives backups of the database

Each job is conditionally executed based on the workflow trigger and specified parameters.

## Environment Variables and Secrets

The workflow requires several environment variables and secrets to function properly:

### Required Secrets

These must be configured in your GitHub repository settings:

- `SSH_PRIVATE_KEY`: SSH private key for server access
- `SSH_KNOWN_HOSTS`: SSH known hosts entry for your server
- `SERVER_HOST`: Hostname or IP address of your server
- `SERVER_USER`: SSH username for server access
- `DEPLOY_PATH`: Path on the server where files should be deployed
- `VPN_DOMAIN`: Domain name for your VPN service
- `PANEL_PATH`: Admin panel access path
- `XUI_USERNAME`: Username for 3x-ui panel
- `XUI_PASSWORD`: Password for 3x-ui panel
- `JWT_SECRET`: Secret for JWT token signing
- `ADMIN_EMAIL`: Admin email address
- `XRAY_VMESS_AEAD_FORCED`: XRay VMESS AEAD forced setting

### Setting Up Secrets

Use the provided script to set up the required secrets:

```bash
./scripts/setup-github-secrets.sh
```

This script will:
1. Check for existing secrets
2. Use values from your local .env file if available
3. Prompt for any missing values
4. Configure the secrets in your GitHub repository

## Deployment Process

The deployment process follows these steps:

1. **Checkout Code**: Retrieves the latest code from the repository
2. **Validate Configuration**: Ensures all configuration files are valid
3. **Setup Server**: Configures the server environment if needed
4. **Transfer Files**: Copies files to the server
5. **Configure Container**: Updates Docker Compose configuration
6. **Start Service**: Starts or restarts the Docker container
7. **Verify Deployment**: Ensures the service is running correctly

### Triggering Deployment

Deployment can be triggered in two ways:

1. **Push to Main Branch**: Any push to the main branch will trigger deployment
2. **Manual Dispatch**: Go to Actions > 3x-ui VPN Service Management > Run workflow

## Backup Process

Backups are automatically created daily and can also be triggered manually.

### Backup Storage

Backups are stored in two locations:

1. **Server**: In the `backups` directory on the server
2. **GitHub**: Uploaded as artifacts to the workflow run

### Restoring from Backup

To restore from a backup:

1. Stop the container: `docker-compose down`
2. Replace the `db/x-ui.db` file with the backup
3. Restart the container: `docker-compose up -d`

## Local Testing

Before pushing changes to GitHub, you can test the workflow locally using the provided script:

```bash
./scripts/test-workflow.sh
```

This script uses [act](https://github.com/nektos/act) to run GitHub Actions workflows locally. It will:

1. List available workflow jobs
2. Ask which job you want to test
3. Optionally perform a dry run
4. Execute the selected job with your local environment variables

### Requirements

- [act](https://github.com/nektos/act) must be installed
- Docker must be running
- Local `.env` file with required variables

## Troubleshooting

### Common Issues

1. **SSH Connection Errors**:
   - Check your SSH key configuration
   - Verify the server's SSH service is running
   - Confirm the server_host and server_user values

2. **Docker Container Issues**:
   - Check Docker logs: `docker-compose logs`
   - Verify port availability: `netstat -tuln`
   - Check disk space: `df -h`

3. **Workflow Failures**:
   - Check the workflow logs in GitHub Actions
   - Verify all secrets are correctly configured
   - Try running the workflow locally with `test-workflow.sh`

### Log Files

Log files are stored in two locations:

1. **Server**: In the `logs` directory on the server
2. **GitHub**: In the `workflow_logs` directory and as artifacts in workflow runs

### Getting Help

If you encounter issues:

1. Check the workflow logs for specific error messages
2. Run the workflow with debug logging enabled
3. Try running the specific job locally using `test-workflow.sh` 