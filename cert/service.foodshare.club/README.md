# SSL Certificates for service.foodshare.club

This directory is maintained for compatibility with the 3x-ui service configuration. The SSL certificates are now managed by your existing Caddy server instead of NGINX/Certbot.

## Certificate Management with Caddy

Caddy automatically handles SSL certificate issuance and renewal through Let's Encrypt using Cloudflare DNS validation. The configuration for this is already set up in your Caddy configuration.

## Integration with 3x-ui

The 3x-ui service is configured to connect to your Caddy service via Docker networks:
- `web` - Main network for web traffic
- `no-zero-trust-cloudflared` - Network for services outside Cloudflare Zero Trust

## Caddy Configuration

See the `docs/caddy-config.md` file for detailed Caddy configuration instructions to properly proxy traffic to the 3x-ui service.

## Troubleshooting

If you encounter certificate validation errors:

1. Check that the domain is properly pointing to your server's IP address
2. Verify that your Cloudflare API token has the necessary permissions
3. Check Caddy logs for certificate issuance errors:
   ```bash
   docker-compose logs caddy | grep -i cert
   ```
4. Ensure your 3x-ui service is properly connected to the Caddy Docker networks 