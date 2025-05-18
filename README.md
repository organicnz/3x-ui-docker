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
   - `XUI_ENFORCE_HTTPS` set to `false`
   - Removed health check that required unavailable tools in the container

3. **Quick Start for Development**:
   ```bash
   # Create necessary directories
   mkdir -p db cert/nginx logs
   
   # Start the container
   docker-compose up -d
   
   # Access the admin panel
   open http://localhost:54321
   ```

4. **Default Credentials**:
   - Username: `admin`
   - Password: `admin`
   
Remember to change the default credentials immediately after first login!