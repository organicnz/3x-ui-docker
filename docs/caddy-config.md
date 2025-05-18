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

    # URL rewrite for port references in HTML/JS
    @rewrite_port_refs path /BXv8SI7gBe*
    handle @rewrite_port_refs {
        # Rewrite HTML responses to fix port references
        reverse_proxy 3x-ui:54321 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
            # Replace port 2053 with the domain in HTML responses
            header_down Content-Type {http.response.header.Content-Type}
            replace_response "service.foodshare.club:2053" "service.foodshare.club"
        }
    }

    # Handle all assets paths explicitly
    handle_path /BXv8SI7gBe/assets/* {
        reverse_proxy 3x-ui:54321 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
        }
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

1. Update your Caddyfile with the configuration above
2. Reload Caddy configuration:
   ```bash
   docker-compose exec caddy caddy reload
   ```

3. Verify the configuration is working:
   ```bash
   docker-compose exec caddy caddy validate
   ```

## Troubleshooting

If you're still seeing ERR_CERT_AUTHORITY_INVALID errors:

1. Check that your Cloudflare API token has the correct permissions (Zone:Read and DNS:Edit)

2. Verify Caddy can connect to Cloudflare:
   ```bash
   docker-compose logs caddy | grep -i cloudflare
   ```

3. Make sure your domain's DNS is properly configured in Cloudflare:
   - Set DNS records for service.foodshare.club to point to your server IP
   - Ensure SSL/TLS settings are set to "Full" in Cloudflare dashboard

4. Check for JavaScript errors in the browser console and ensure URLs are being properly rewritten:
   ```bash
   # Verify URL rewriting is working
   curl -v "https://service.foodshare.club/BXv8SI7gBe" | grep -i 2053
   ```

5. Make sure 3x-ui container is properly connected to Caddy networks:
   ```bash
   docker inspect 3x-ui | grep -A 20 "Networks"
   ``` 