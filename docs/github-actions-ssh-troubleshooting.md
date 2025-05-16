# GitHub Actions SSH Connection Troubleshooting

## Problem Identification

The deployment workflow is failing with the error:
```
Warning: Identity file -----BEGIN not accessible: No such file or directory.
ssh: Could not resolve hostname openssh: Temporary failure in name resolution
```

This indicates that GitHub Actions is misinterpreting your SSH key format.

## Fix the SSH Key in GitHub Secrets

### 1. Verify your SSH key format locally

```bash
# Check your existing key format
./scripts/check-ssh-key.sh ~/.ssh/id_rsa_gitlab
```

Your key should include the BEGIN and END markers:
```
-----BEGIN OPENSSH PRIVATE KEY-----
(key content)
-----END OPENSSH PRIVATE KEY-----
```

### 2. Add SSH_KNOWN_HOSTS Secret

Generate a proper known_hosts entry for your server:

```bash
# Replace with your actual server IP or hostname
./scripts/generate-known-hosts.sh your-server-hostname
```

Add this output as a GitHub Secret named `SSH_KNOWN_HOSTS`.

### 3. Fix the GitHub Workflow Issue

The error suggests that the workflow might be passing the SSH key incorrectly. Check these workflow settings:

1. In the `webfactory/ssh-agent@v0.7.0` step, ensure your key is being set properly:
   ```yaml
   - name: 🔑 Set up SSH
     uses: webfactory/ssh-agent@v0.7.0
     with:
       ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
   ```

2. For the manual SSH commands, update them to use the configured SSH agent:
   ```yaml
   # INCORRECT:
   ssh -i ${{ secrets.SSH_PRIVATE_KEY }} -o StrictHostKeyChecking=no ...
   
   # CORRECT:
   ssh -o StrictHostKeyChecking=no ...
   ```

### 4. Required GitHub Secrets

Ensure you have all these secrets set properly:
- `SSH_PRIVATE_KEY`: Your full private key, including BEGIN/END lines
- `SSH_KNOWN_HOSTS`: Output from the generate-known-hosts.sh script
- `SERVER_HOST`: Your server's hostname or IP
- `SERVER_USER`: Your SSH username on the server
- `DEPLOY_PATH`: Path on the server where files should be deployed
- `VPN_DOMAIN`: Domain for your VPN service
- `ADMIN_EMAIL`: Email for Let's Encrypt certificate

## Testing SSH Connection Locally

Verify that you can connect to your server using the same key:

```bash
# Test SSH connection with the same key
ssh -i ~/.ssh/id_rsa_gitlab your-username@your-server
```

If this works but GitHub Actions fails, the issue is in how GitHub Actions is using the key.

## Common Pitfalls

1. **Multi-line secrets**: GitHub Actions handles multi-line secrets correctly, but you must paste the entire key including newlines
2. **Key permissions**: Your local key should have proper permissions (chmod 600)
3. **Authorized keys**: Ensure the public key is in the server's authorized_keys file
4. **Agent forwarding**: The GitHub workflow must use ssh-agent correctly

## Next Steps

After fixing these issues, trigger a new workflow run and check the logs for any new errors. 