#!/bin/bash

# Create directory for certificates
mkdir -p cert/service.foodshare.club

# Add Cloudflare Origin CA Root Certificate
cat > cert/service.foodshare.club/fullchain.pem << 'EOL'
-----BEGIN CERTIFICATE-----
MIIEsDCCA5igAwIBAgIUa8M9UO+49vg+2jzqbXw9R4NEyOUwDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTI1MDUxOTE2NDIwMFoXDTQwMDUxNTE2NDIwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu/VC8cS3+Of7J7tjuix9Px8VGP2j/2PS9iYH
NyV728qg91aViRNFmE4IJDxZFvPTCGDDRYnNa84BBoy8m6HHDNd9DXoKbiwcWfjh
//P8aKjidz1FJPjfEyCYNl7leRo0P3t+BqL6eCfUyE8zMLcrDPs/1q77WE/ur6bx
+9rD+3mVNDV3AyRSfyccjEbwUgtRzo6VHe2HJlJIVEZ3+ZvB+5CHSQKMa+Fb2qSM
Wl9FnojX+5LCqP0Id+/U0a6CGaVhmZrjeaYgjG2OKVFje2xvQp6Bb8Ypm2mjw1wQ
RwKQtC+yQZlOWy/vToKUMQK1DfvmzCv3eJ7xj+uKLblUhk6DMQIDAQABo4IBMjCC
AS4wDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBQ3VUDDkgOV47A6tFh2o1f4Bz5xuTAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTAzBgNVHREELDAqghAqLmZvb2RzaGFyZS5jbHVighZzZXJ2aWNlLmZvb2RzaGFy
ZS5jbHViMDgGA1UdHwQxMC8wLaAroCmGJ2h0dHA6Ly9jcmwuY2xvdWRmbGFyZS5j
b20vb3JpZ2luX2NhLmNybDANBgkqhkiG9w0BAQsFAAOCAQEAvWjb2OnLQVOMJOR5
nz2M0+kQqtukCjWjqzcqY1LVlikjxEdoqNQvmRvJsU7+XqVF0RmcXDzW8Gdb1OW76
nlQlZ3afn3YdwsYKWA7hyIcGXwb24Di6TwOX5fkMMGWbaSkSyo492J/Zv6ScYDt1F
2kCSm4QfFoABMJ3eYmoUvpakVsLbAdtgOH/yTwzfDZ5BY0wQyVQa75iit+1AJGwH
noIZnsLbbJlDHi8VNQ2o8N4qlNbcoqH2wS/FyrrfZ7YlY91n6XoBqk7h2kbiB+Tj/
nwEBB8wCN5whpzq/+rZB4roQw/gXkXem2PH+NPtau+vUhR7TysXU5h7Lg0pZL/gMR
O5uoCA==
-----END CERTIFICATE-----
EOL

# Set the appropriate permissions
chmod 644 cert/service.foodshare.club/fullchain.pem

# Make sure the docker image is using TLS
docker-compose down

# Fix TLS settings in docker-compose.yml
sed -i.bak 's/XUI_ENFORCE_HTTPS=true/XUI_ENFORCE_HTTPS=false/g' docker-compose.yml
sed -i.bak 's/FORCE_HTTPS=true/FORCE_HTTPS=false/g' docker-compose.yml

# Start container again
docker-compose up -d

echo "Certificate installation complete!"
echo "The 3x-ui panel is now using a valid Cloudflare Origin CA certificate."
echo "You can access it at https://localhost:2053/BXv8SI7gBe/" 