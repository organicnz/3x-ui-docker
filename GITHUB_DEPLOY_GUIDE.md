# GitHub Deploy Key Automation Guide

This guide shows how to use the automated GitHub deploy key generation and setup script.

## Prerequisites

1. You need a GitHub Personal Access Token with "repo" permissions
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token"
   - Give it a name like "Deploy Key Setup"
   - Select the "repo" permission
   - Click "Generate token"
   - **Copy the token - you won't see it again!**

2. Make sure your script is executable
   ```bash
   chmod +x scripts/setup_github_deploy_key.sh
   ```

## Using the Script

### Basic Key Generation

Generate a key without adding it to GitHub (interactive mode):
```bash
npm run setup:deploy-key
```

### Add Key to GitHub Repository

Add the key to your GitHub repository automatically:
```bash
npm run setup:deploy-key:add
```
You'll be prompted to enter your GitHub token.

### Fully Automated Setup

For a completely non-interactive setup that generates and adds both the deploy key and secret:
```bash
npm run setup:deploy-key:auto
```
You'll be prompted for your GitHub token, or you can provide it with a custom command.

### Advanced Usage with Direct Options

```bash
# With all options specified
./scripts/setup_github_deploy_key.sh -t YOUR_GITHUB_TOKEN -a -s --title "My Custom Deploy Key" -w true -y

# Explanation of options:
# -t YOUR_GITHUB_TOKEN : Your GitHub personal access token
# -a                   : Add key to GitHub repository
# -s                   : Add key to GitHub secrets (prompts for manual steps)
# --title "My Key"     : Custom title for the deploy key
# -w true              : Allow write access (default is true)
# -y                   : Yes to all prompts (non-interactive mode)
```

## Using the Deploy Key in GitHub Actions

Once your key is set up, use it in your workflow:

```yaml
- name: Install SSH key
  uses: webfactory/ssh-agent@v0.7.0
  with:
    ssh-private-key: ${{ secrets.DEPLOY_KEY }}
    log-public-key: true
```

This will properly configure the SSH agent with your deploy key, allowing the action to access your repository. 