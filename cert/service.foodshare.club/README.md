# SSL Certificates for service.foodshare.club

Place your SSL certificates in this directory:

1. `fullchain.pem` - The full certificate chain file
2. `privkey.pem` - The private key file

## How to obtain certificates

You can obtain SSL certificates for your domain using Let's Encrypt:

```bash
# Using Certbot (recommended)
certbot certonly --standalone -d service.foodshare.club

# Then copy the certificates to this directory:
cp /etc/letsencrypt/live/service.foodshare.club/fullchain.pem ./fullchain.pem
cp /etc/letsencrypt/live/service.foodshare.club/privkey.pem ./privkey.pem
```

## Certificate files structure

The container expects to find these files at:
- `/root/cert/service.foodshare.club/fullchain.pem`
- `/root/cert/service.foodshare.club/privkey.pem`

This directory is mounted to `/root/cert` in the Docker container. 