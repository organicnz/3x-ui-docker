# SSL Certificates for service.foodshare.club

This directory will store SSL certificates for your service.foodshare.club domain. The certificates are automatically managed using Certbot and Let's Encrypt.

## Automated Certificate Management

The Docker Compose configuration now includes:

1. A Certbot container that automatically obtains and renews SSL certificates
2. An NGINX container that handles SSL termination and proxies requests to the 3x-ui service

## Certificate Structure

After running the stack, the following files will be automatically generated:

- `live/service.foodshare.club/fullchain.pem` - The full certificate chain file
- `live/service.foodshare.club/privkey.pem` - The private key file

These files are referenced by the NGINX configuration and will be used for SSL termination.

## Manual Certificate Management (If Needed)

If you need to manually manage certificates:

```bash
# Using Certbot manually
docker-compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot \
  --email admin@foodshare.club --agree-tos --no-eff-email \
  --force-renewal -d service.foodshare.club
```

## Certificate Renewal

Certificates from Let's Encrypt are valid for 90 days. The NGINX configuration includes automatic reload every 6 hours to pick up renewed certificates.

## Troubleshooting

If you encounter certificate validation errors:

1. Check that the domain is properly pointing to your server's IP address
2. Verify that ports 80 and 443 are open in your firewall
3. Check the Certbot logs: `docker-compose logs certbot`
4. Check the NGINX logs: `docker-compose logs nginx` 