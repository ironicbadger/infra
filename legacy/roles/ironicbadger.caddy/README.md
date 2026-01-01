# ansible-role-caddy

Install and configure Caddy reverse proxy programatically. Tested on Ubuntu 24.04.

## Variables
TLS providers
```yaml
caddy_tls_providers:
  - provider: cloudflare
    challenge_type: dns
    provider_api_token: "1234567890abcdefg"
    resolver_ip: 1.1.1.1
```

Endpoints
```yaml
caddy_endpoints:
  - friendly_name: app1
    fqdn: app1.exaple.com
    upstream: "localhost:8081"
    tls_insecure: false
    tls_provider: cloudflare
  - friendly_name: Wildcard *.local.example.com
    fqdn: '*.local.exaple.com'
    tls_provider: cloudflare
    wildcard_endpoints:
      - friendly_name: app2
        fqdn: app2.local.example.com
        upstream: "localhost:8082"
        tls_insecure: false
```

