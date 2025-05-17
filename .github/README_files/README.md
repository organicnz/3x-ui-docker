# GitHub Supporting Files

This directory contains various support files for GitHub features:

- `/workflows` - GitHub Actions workflow files
- `/README_files` - Images and other supporting files for the main README.md

## Directory Structure

The overall project is organized as follows:

```
3x-ui-vpn/
├── .github/               # GitHub-specific files
│   └── workflows/         # GitHub Actions workflows
├── cert/                  # SSL certificates
│   └── service.foodshare.club/ # Domain-specific certificates
├── db/                    # Database files
│   └── x-ui.db            # SQLite database for 3x-ui
├── docs/                  # Documentation files
├── logs/                  # Log files
├── scripts/               # Utility scripts
├── workflow_logs/         # Logs from workflow runs
├── .env.example           # Example environment file
├── docker-compose.yml     # Docker Compose configuration
└── README.md              # Main README file
```

## Best Practices

1. Always store SSL certificates in the `cert/[domain-name]/` directory
2. Keep database files in the `db/` directory
3. Store logs in the `logs/` directory
4. Use `.env` for configuration (copied from `.env.example`)
5. Run scripts from the `scripts/` directory 