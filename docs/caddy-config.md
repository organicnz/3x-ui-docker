# Caddy Configuration for 3x-ui VPN Service

## Overview
This file contains the recommended Caddy configuration for the 3x-ui VPN service. It addresses common issues like:

- SSL certificate management
- Security headers
- Correct proxy settings
- Browsing-topics header errors

## Installation

1. Copy this configuration to your Caddy server.
2. Reload Caddy: `caddy reload`

## Caddyfile Configuration

```caddyfile
{
    # Global options block
    email admin@example.com  # Replace with your email
    # Optional staging lets encrypt for testing. Comment out for production.
    # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

# VPN Admin Panel
service.foodshare.club {
    # TLS configuration with Cloudflare DNS validation
    tls {
        # Use the following line if you have Cloudflare API token
        # dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }

    # Proper headers without browsing-topics
    header {
        # Remove Permissions-Policy browsing-topics to avoid warnings
        Permissions-Policy "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=(), gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()"
        
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # Cache control for dynamic content
        Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate"
        Pragma "no-cache"
        Expires "0"
    }

    # Reverse proxy to 3x-ui
    reverse_proxy localhost:2053 {
        # Health checks
        health_path /BXv8SI7gBe/
        health_interval 30s
        
        # Header adjustments
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote}
        header_up X-Forwarded-For {http.request.remote}
        header_up X-Forwarded-Proto {http.request.scheme}
    }

    # Logging
    log {
        output file /var/log/caddy/service.foodshare.club.log {
            roll_size 10mb
            roll_keep 5
        }
    }
}
```

## Troubleshooting

### Headers Issues
If you encounter warnings about unrecognized features in the Permissions-Policy header:

1. Remove the problematic feature from the header list
2. Reload Caddy with `caddy reload`

### Certificate Issues
If you encounter certificate issues:

1. Ensure Caddy has proper permissions to issue certificates
2. Check Caddy logs: `tail -f /var/log/caddy/service.foodshare.club.log`
3. For Cloudflare DNS validation, ensure your API token has proper permissions

## Best Practices

1. Always use HTTPS
2. Regularly update your Caddy server
3. Set up proper backup for your certificates
4. Use strong security headers
5. Configure proper logging for troubleshooting 