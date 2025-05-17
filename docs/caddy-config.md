# Caddy Configuration for 3x-ui VPN Service

## Overview

This document provides the necessary Caddy configuration to proxy traffic to the 3x-ui VPN service. Add these snippets to your existing Caddyfile.

## Caddyfile Configuration

Add the following to your `Caddyfile`:

```caddyfile
# VPN Admin Panel (service.foodshare.club)
service.foodshare.club {
    # TLS configuration with Cloudflare DNS validation
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }

    # Remove Permissions-Policy browsing-topics to avoid warnings
    header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=(), gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()"

    # Proxy to 3x-ui admin panel
    handle /BXv8SI7gBe* {
        reverse_proxy 3x-ui:54321
    }

    # Proxy to XRay services on port 2053
    handle {
        reverse_proxy 3x-ui:2053 {
            # Support WebSocket
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
            header_up Upgrade {http.request.header.Upgrade}
            header_up Connection {http.request.header.Connection}
        }
    }

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # Log configuration
    log {
        output file /data/logs/service.foodshare.club.log {
            roll_size 10mb
            roll_keep 5
            roll_keep_for 720h
        }
    }
}
```

## Implementation Steps

1. Add the above configuration to your Caddyfile
2. Reload Caddy configuration:
   ```bash
   docker-compose exec caddy caddy reload
   ```

3. Verify the configuration is working:
   ```bash
   docker-compose exec caddy caddy validate
   ```

## Troubleshooting

If you encounter issues:

1. Check Caddy logs:
   ```bash
   docker-compose logs caddy
   ```

2. Verify 3x-ui service is running:
   ```bash
   docker-compose logs 3x-ui
   ```

3. Make sure the services are on the same Docker network:
   ```bash
   docker network inspect web
   ```

4. Test direct connection to 3x-ui within the Docker network:
   ```bash
   docker-compose exec caddy curl -v http://3x-ui:54321/BXv8SI7gBe
   ``` 