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

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [3x-ui Project](https://github.com/MHSanaei/3x-ui)
- [XRay Core](https://github.com/XTLS/Xray-core) 