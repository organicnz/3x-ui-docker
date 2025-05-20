# 3x-ui VPN Service

A Docker-based deployment of the 3x-ui panel for XRay VPN services with persistent database storage.

## Overview

This repository contains configuration for deploying and managing a 3x-ui VPN service using Docker and GitHub Actions. The setup maintains persistent storage of the SQLite database (x-ui.db) to ensure data is preserved between container restarts and deployments.

## Features

- **Docker-based deployment** - Easy deployment and management
- **Persistent SQLite storage** - Data persists between container restarts
- **Automated deployment** - GitHub Actions workflow for CI/CD
- **Automated backups** - Daily database backups
- **Health monitoring** - Container health checks

## Prerequisites

- Docker and Docker Compose
- Server with SSH access
- GitHub repository with secrets configured

## Setup Instructions

### 1. GitHub Secrets

Configure the following secrets in your GitHub repository:

- `SSH_PRIVATE_KEY` - SSH private key for server access
- `SSH_KNOWN_HOSTS` - SSH known hosts entry for your server
- `SERVER_HOST` - Hostname or IP address of your server
- `SERVER_USER` - SSH username for server access
- `DEPLOY_PATH` - Path on the server where files should be deployed

### 2. Automated Management Workflow

We provide a consolidated GitHub Actions workflow for managing all aspects of your 3x-ui deployment:

1. Go to the Actions tab in your GitHub repository
2. Select the "3x-ui VPN Service Management" workflow
3. Click "Run workflow"
4. Select the operation you want to perform:
   - `setup`: Initial server configuration
   - `deploy`: Deploy or update the 3x-ui service
   - `backup`: Create and download a backup of the database
5. Choose the target environment (production or staging)
6. Click "Run workflow" again

This workflow handles:
- **Initial Setup**: Creates directories, installs dependencies, and configures the server
- **Deployment**: Transfers files and manages the Docker container
- **Backup**: Creates and archives database backups

Additionally, the workflow automatically:
- Runs deployment when you push changes to the main branch
- Performs daily backups at 2:00 AM UTC

### 3. Access the 3x-ui Panel

Once deployed, you can access the 3x-ui panel at:

```
https://your-server-ip:54321
```

Default credentials:
- Username: `admin`
- Password: `admin`

**Important**: Change the default credentials immediately after first login!

## Persistent Storage

The Docker Compose configuration mounts the local `x-ui.db` file into the container, ensuring that all data is persistent. This includes:

- User accounts
- Inbound configurations
- Client configurations
- Traffic statistics

## Backup and Recovery

### Automated Backups

Daily backups are configured to run at 2 AM UTC. These backups:
1. Create a timestamped copy of the x-ui.db file
2. Compress the backup with gzip
3. Retain the 7 most recent backups on the server
4. Download the latest backup to GitHub Actions

### Manual Backup

You can manually trigger a backup from the Actions tab in GitHub:
1. Select the "3x-ui VPN Service Management" workflow
2. Click "Run workflow"
3. Select `backup` as the workflow type
4. Choose your target environment
5. Click "Run workflow" again

### Recovery

To restore from a backup:

1. Stop the container: `docker-compose down`
2. Replace the `x-ui.db` file with the backup
3. Restart the container: `docker-compose up -d`

## Security Recommendations

1. Change default admin credentials immediately
2. Use strong passwords for all accounts
3. Configure 2FA for the admin panel
4. Limit administrative access by IP
5. Regularly update the container image

## Maintenance

### Updating

To update to the latest version:

1. Pull the latest changes from GitHub
2. Trigger the deployment workflow

### Monitoring

Check the container status:

```bash
docker-compose ps
docker-compose logs
```

## Troubleshooting

### Container fails to start

Check logs for errors:

```bash
docker-compose logs
```

### Database issues

If the database becomes corrupted, restore from a backup or reset it:

```bash
# Stop container
docker-compose down

# Restore from backup
cp backups/x-ui.db.backup_TIMESTAMP x-ui.db

# Start container
docker-compose up -d
```

## Error Checking Tools

We provide several CLI tools to help you quickly check for errors in both the remote server and GitHub workflow runs:

### Remote Server Error Checking

Check for errors in the 3x-ui container logs:

```bash
./scripts/check-remote-errors.sh
```

Options:
- `--full`: Show full logs without filtering for errors
- `--lines=N`: Show last N lines (default: 50)
- `--all`: Show all log entries, not just errors

### GitHub Workflow Error Checking

Check for errors in GitHub Actions workflow runs:

```bash
./scripts/check-workflow-logs.sh
```

Options:
- `--latest`: Check logs from the latest workflow run (default)
- `--workflow-id=<id>`: Check logs from a specific workflow ID
- `--run-id=<id>`: Check logs from a specific run ID

### Combined Error Checking

Check both server and workflow errors in one command:

```bash
./scripts/check-errors.sh
```

Options:
- `--server`: Check only server errors
- `--workflow`: Check only workflow errors
- `--all`: Check both (default if no option specified)
- `--server-full`: Show full server logs
- `--server-all`: Show all server log entries
- `--lines=N`: Show last N lines of logs
- `--workflow-latest`: Check latest workflow run
- `--run-id=<id>`: Check specific run ID

The logs are saved in the `workflow_logs` directory, and a symlink to the latest run is always maintained at `workflow_logs/run-latest`.

### Local Container Status

Check the status and logs of your local Docker container:

```bash
./scripts/check-container-status.sh
```

Options:
- `--logs`: Show only container logs
- `--stats`: Show only container statistics
- `--all`: Show both logs and stats (default)
- `--lines=N`: Show last N lines of logs (default: 50)
- `--container=NAME`: Specify container name (default: 3x-ui)

This is useful for quick local debugging without having to remember various Docker commands.

### Comprehensive Status Report

Generate a complete status report that checks local and remote components and saves the result to a log file:

```bash
./scripts/status-report.sh
```

Options:
- `--full`: Generate a full detailed report with more log lines
- `--output=FILE`: Save the report to a specific file (default: logs/status-report_TIMESTAMP.log)

This script combines all the error checking tools above into a single comprehensive report for troubleshooting. It includes:
- System information
- Local container status and logs
- Remote server logs
- GitHub workflow status

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Development Workflow

### Project Structure

The project is organized as follows:

- **docker-compose.yml**: Main Docker Compose configuration
- **scripts/**: Contains utility scripts for development and deployment
  - **commit.sh**: Script for standardized commit messages
- **.github/workflows/**: GitHub Actions workflow definitions
- **x-ui.db**: SQLite database for persistent storage

### Commit Rules

This project follows strict commit message conventions to maintain a clean and meaningful git history.

#### ⚠️ IMPORTANT: ALWAYS USE THE AUTO-COMMIT SCRIPT ⚠️

**All team members must use our auto-commit script instead of regular git commands:**

```bash
npm run commit "description of changes" "Type"
```

Example:
```bash
npm run commit "add dark mode toggle" "Feat"
```

The script automatically:
- Formats the commit message according to our standards
- Determines the appropriate scope based on modified files
- Stages all changes in the working directory
- Commits and pushes the changes to the main branch **without asking for confirmation**

#### Commit Format

All commit messages follow this format:
```
<type>(<scope>): <description>
```

Where:
- `<type>`: The type of change (see below)
- `<scope>`: The area of the codebase affected (component, feature, etc.)
- `<description>`: A brief description of the change

#### Types of Commits
- **Feat**: New feature or functionality
  - Example: `Feat(player): add audio speed control`
- **Fix**: Bug fix
  - Example: `Fix(api): resolve authentication token expiration issue`
- **Docs**: Documentation changes
  - Example: `Docs(readme): update installation instructions`
- **Refactor**: Code changes that neither fix bugs nor add features
  - Example: `Refactor(utils): simplify date formatting functions`
- **Style**: Changes related to styling, formatting, or UI (not affecting functionality)
  - Example: `Style(tailwind): update button hover states`
- **Test**: Adding or updating tests
  - Example: `Test(unit): add tests for user authentication`
- **Chore**: Maintenance tasks, dependency updates, etc.
  - Example: `Chore(deps): update dependencies to latest versions`

#### Using the Auto-commit Tool

The commit script automatically:
- Formats the commit message according to our standards
- Determines the appropriate scope based on modified files
- Stages all changes in the working directory
- Commits and pushes the changes to the main branch **without asking for confirmation**

##### Interactive Mode
If you don't provide arguments, the script will prompt you for information:

```bash
npm run commit
```

This will:
1. Show you a list of valid commit types
2. Ask for your commit message
3. Ask you to select a commit type
4. Automatically commit and push the changes

##### Direct Mode
For quicker commits, provide the message and type directly:

```bash
npm run commit "your commit message" "Type"
```

## Acknowledgements

- [3x-ui Project](https://github.com/MHSanaei/3x-ui)
- [XRay Core](https://github.com/XTLS/Xray-core) 

## Administration Scripts

We've created several utility scripts to help you manage your VPN deployment. The scripts now use a shared utilities library to ensure consistency and avoid code duplication.

### Main Administration Tool

The main administration tool provides a menu-driven interface for all management tasks:

```bash
./scripts/vpn-admin.sh
```

This tool allows you to:
- Set up your environment variables
- View GitHub Actions workflow status
- Fetch and view remote logs
- Deploy the VPN service
- SSH to the VPN server
- Check server status

### Individual Scripts

If you prefer to use individual scripts:

#### Environment Setup
```bash
./scripts/setup-env.sh
```
This script creates a `.env` file from the example template and helps you configure the required variables.

#### Workflow Logs
```bash
./scripts/workflow-logs.sh [options]
```
Options:
- `-l, --latest`: Show latest logs (default)
- `-f, --fetch`: Fetch logs from the remote server
- `-a, --all`: Show all available logs
- `-g, --github`: Instructions for checking GitHub Actions logs
- `-e, --env`: Show loaded environment variables
- `-c, --check`: Check remote server setup

#### Workflow Status
```bash
./scripts/check-workflow-status.sh [options]
```
Options:
- `-h, --help`: Show help message
- `-l, --limit N`: Show N most recent workflow runs (default: 5)
- `-a, --all`: Show all workflow runs

### Shared Utilities Library

All these scripts use a common utilities library (`scripts/utils.sh`), which provides:

- Standardized environment variable loading
- Common SSH functions
- Directory and file management functions
- Consistent color formatting

### Environment Variables

The scripts use the following environment variables (stored in `.env`):

```
SERVER_HOST=your-server-hostname
SERVER_USER=username
DEPLOY_PATH=/path/to/3x-ui
SSH_KEY_PATH=/path/to/your/ssh/key (optional)
REPO_OWNER=github-username
REPO_NAME=repository-name
```
To set these up automatically, run `./scripts/setup-env.sh`.

## Local Development Setup

For local development and testing, the following modifications have been made to the docker-compose.yml file:

1. **Local Bridge Network**: Using a local bridge network instead of external networks
   - No need to create external networks before running
   - Self-contained development environment

2. **Simplified Configuration**: 
   - `BASE_URL` set to `http://localhost`
   - `XUI_ENFORCE_HTTPS` set to `false` (though the panel uses HTTPS internally)
   - Custom panel path is set to `BXv8SI7gBe`

3. **Quick Start for Development**:
   ```bash
   # Create necessary directories and start the container
   ./scripts/local-setup.sh
   
   # Or open the panel directly if already set up
   ./scripts/open-panel.sh
   ```

4. **Access the Admin Panel**:
   - URL: `https://localhost:54321/BXv8SI7gBe/`
   - Username: `admin`
   - Password: `admin`
   
Remember to change the default credentials immediately after first login!

**Note**: The panel uses a self-signed certificate, so your browser may show a security warning. This is expected in a local development environment.

## Environment Variables and GitHub Secrets

This project uses environment variables to configure the 3x-ui VPN service. For proper security, sensitive values are stored as GitHub secrets and injected during deployment.

### Required GitHub Secrets

For CI/CD to work correctly, set up the following GitHub secrets:

- `PANEL_PATH`: The secure path for accessing the admin panel (e.g., `BXv8SI7gBe`)
- `HTTPS_PORT`: Port for accessing the admin interface (default: `2053`)
- `VPN_DOMAIN`: The domain name for your VPN service (e.g., `service.foodshare.club`)
- `ADMIN_EMAIL`: Email address for certificate notifications
- `XRAY_VMESS_AEAD_FORCED`: Whether to force AEAD for VMESS (default: `false`)
- `XUI_USERNAME`: Admin username for 3x-ui panel
- `XUI_PASSWORD`: Admin password for 3x-ui panel
- `JWT_SECRET`: Secret key for JWT token generation

### Deployment Secrets

- `SSH_PRIVATE_KEY`: SSH private key for deployment
- `SSH_KNOWN_HOSTS`: SSH known hosts for secure connection
- `SERVER_USER`: Username for SSH connection
- `SERVER_HOST`: Hostname or IP address of the server
- `DEPLOY_PATH`: Path where the project is deployed on the server

### Local Development

For local development, you can create a `.env` file based on the following template:

```env
# 3x-ui VPN Service Configuration - Local Development
PANEL_PATH=BXv8SI7gBe
HTTPS_PORT=2053
VPN_DOMAIN=service.foodshare.club
ADMIN_EMAIL=admin@example.com
XRAY_VMESS_AEAD_FORCED=false
XUI_USERNAME=admin
XUI_PASSWORD=admin
JWT_SECRET=change_me_to_a_secure_random_string
```

### CI/CD Workflow

The GitHub Actions workflow automatically:

1. Generates a `.env` file from GitHub secrets
2. Uses the environment variables in the Docker Compose configuration
3. Deploys the service to the specified server

This approach ensures that sensitive values are never committed to the repository and are securely passed to the application during deployment.

## Running the Service

To start the service locally:

```bash
docker-compose up -d
```

Access the admin panel at http://localhost:2053/BXv8SI7gBe/ (replace with your configured values).

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/3x-ui-vpn.git
   cd 3x-ui-vpn
   ```

2. Add the domain to your hosts file:
   ```bash
   sudo ./update_hosts.sh
   ```

3. Start the service:
   ```bash
   docker-compose up -d
   ```

4. Access the admin panel at: http://service.foodshare.club:2053/BXv8SI7gBe/
   - Default credentials: admin/admin (unless changed in the environment)

## Troubleshooting SSL Certificate Issues

If you're experiencing certificate validation errors with the admin panel:

### Option 1: Access via HTTP

The easiest solution is to access the admin panel via HTTP instead of HTTPS:
- Use http://service.foodshare.club:2053/BXv8SI7gBe/ (note the `http://` protocol)

### Option 2: Bypass SSL Warnings (For Testing Only)

We've included a script to launch Chrome with certificate warnings disabled:
```bash
./bypass_ssl_warning.sh
```

⚠️ **WARNING**: This is only for local testing and development. It disables security features in Chrome.

### Option 3: Install Self-Signed Certificate

For a more permanent solution, you can add the self-signed certificate to your trusted certificates store.

#### MacOS:
1. Open the Keychain Access app
2. Import `cert/service.foodshare.club/fullchain.pem`
3. Find the imported certificate in your keychain
4. Double-click on it, expand the "Trust" section
5. Set "When using this certificate" to "Always Trust"

#### Windows:
1. Double-click on `cert/service.foodshare.club/fullchain.pem`
2. Install the certificate to the "Trusted Root Certification Authorities" store

#### Linux:
```bash
sudo cp cert/service.foodshare.club/fullchain.pem /usr/local/share/ca-certificates/service.foodshare.club.crt
sudo update-ca-certificates
```

## Environment Variables

Edit `.env` to configure the service:

```
VPN_DOMAIN=service.foodshare.club
PANEL_PATH=BXv8SI7gBe
XUI_USERNAME=admin
XUI_PASSWORD=admin
JWT_SECRET=change_me_in_production
XRAY_VMESS_AEAD_FORCED=false
ADMIN_EMAIL=admin@example.com
```

## For Production Use

For production deployment:

1. Replace self-signed certificates with valid ones (Let's Encrypt)
2. Change the default admin credentials
3. Update JWT_SECRET to a strong random string
4. Configure proper firewall rules
5. Set up monitoring and alerting