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

    # Proper headers without browsing-topics
    header {
        # Remove Permissions-Policy browsing-topics to avoid warnings
        Permissions-Policy "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=(), gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()"
        
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # Disable caching for admin panel assets to prevent stale resources
        Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate"
        Pragma "no-cache"
        Expires "0"
    }

    # Special handling for admin panel assets
    @assets {
        path */assets/* */assets/css/* */assets/js/* */assets/vue/* */assets/moment/* */assets/ant-design-vue/* */assets/axios/*
    }

    # Direct assets to 3x-ui server without path rewriting
    handle @assets {
        reverse_proxy 3x-ui:54321 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
        }
    }

    # Proxy to 3x-ui admin panel with proper path handling
    handle_path /BXv8SI7gBe* {
        reverse_proxy 3x-ui:54321
    }

    # Proxy to XRay services
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

2. Test if the 3x-ui service is accessible:
   ```bash
   curl -v http://3x-ui:54321/BXv8SI7gBe
   ```

3. Verify that assets are being properly served:
   ```bash
   curl -I http://service.foodshare.club/BXv8SI7gBe/assets/vue/vue.min.js
   ```

4. Check if Docker networks are properly set up:
   ```bash
   docker network inspect web
   docker network inspect no-zero-trust-cloudflared
   ```

5. Make sure 3x-ui is connected to the appropriate networks:
   ```bash
   docker inspect 3x-ui | grep -A 10 "Networks"
   ``` 