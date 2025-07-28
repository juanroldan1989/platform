# DNS and HTTPS Reachability Overview for `hello-world` app

This document explains the components involved in securely exposing `hello-world-app-london`

to the public internet over HTTPS **using GitOps and ArgoCD.**

It also includes a quick debug tip using `/etc/hosts`.

## DNS & HTTPS Flow Overview

### 1. **ExternalDNS**

- **Purpose:** Automatically manages DNS records in Cloudflare based on Kubernetes resources (Ingresses).
- **How it works:**

  - Watches Ingress resources.
  - For any `host` found (e.g., `app.london.automatalife.com`), it creates or updates corresponding A and TXT records in your Cloudflare DNS zone.

- **Syncs every:** 1 minute.
- **Key Config:**

  - Connected to Cloudflare using a `cloudflare-api-token` secret.

### 2. **Cloudflare API Token Secret**

- **Purpose:** Provides access to Cloudflare's DNS API.
- **Details:**

  - Managed via External Secrets Operator (ESO).
  - Replicated into both `external-dns` and `cert-manager` namespaces.
  - Token must have `Zone.DNS:Edit` permissions.

### 3. **ClusterIssuer**

- **Purpose:** Defines how cert-manager should obtain TLS certificates.
- **Type:** ACME + DNS-01 challenge using Cloudflare.
- **Important fields:**

  - `email`: contact address for Let's Encrypt.
  - `server`: Let's Encrypt ACME URL.
  - `apiTokenSecretRef`: points to the `cloudflare-api-token` secret (in `cert-manager` namespace).

### 4. **cert-manager**

- **Purpose:** Automatically requests and renews TLS certificates from Let's Encrypt.
- **How it works:**

  - Uses the ClusterIssuer to create a wildcard certificate for `*.london.automatalife.com`.
  - Validates DNS-01 challenge using the secret injected by ESO.
  - Stores the final cert in a Kubernetes TLS secret (e.g., `london-wildcard-tls`).

### 5. **NGINX Ingress Controller**

- **Purpose:** Acts as a Layer 7 (HTTP/HTTPS) load balancer.
- **How it works:**

  - Listens on public IP (e.g., `74.220.20.97`) exposed via LoadBalancer service.
  - Routes HTTPS requests to the correct service (`hello`) using the Ingress definition.

### 6. **hello-world App**

- **Purpose:** Simple test app deployed via GitOps.
- **Resources:** One YAML containing:

  - Deployment
  - Service
  - Ingress (uses `london-wildcard-tls` for TLS termination)

- **Route exposed:** `https://app.london.automatalife.com`

---

## Quick DNS Debug via /etc/hosts

If global DNS hasn't propagated yet, test locally by adding this entry:

```bash
sudo nano /etc/hosts
```

```text
74.220.20.97   app.london.automatalife.com
```

Then you can test:

```bash
curl -v https://app.london.automatalife.com
```

Or open it in your browser.

> Remember to remove the entry later to avoid stale DNS routing.

---

## Summary of Interactions

```mermaid
graph TD
  User[User] -->|HTTPS Request| Cloudflare
  Cloudflare -->|Routes via A Record| Ingress[NGINX Ingress Controller]
  Ingress -->|TLS via Secret| CertManager[cert-manager]
  Ingress -->|Forwards to| HelloApp[hello-world App]
  CertManager -->|Uses| ClusterIssuer
  ClusterIssuer -->|Validates via| CloudflareDNS[Cloudflare DNS API]
  ExternalDNS -->|Creates A/TXT| Cloudflare
  ESO -->|Syncs Secret| CertManager & ExternalDNS
```

## DNS & Ingress Debugging – Step-by-Step

This section outlines how we diagnosed and resolved issues while bringing

`hello-world` online via `app.london.automatalife.com` and `app.frankfurt.automatalife.com`.

### Step 1: Check LoadBalancer service status

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

- Ensure EXTERNAL-IP is assigned.

- Validate that type is LoadBalancer.

### Step 2: Confirm Ingress host exists

```bash
kubectl get ingress -A
```

- Ensure the host matches the desired `FQDN` (e.g. `app.frankfurt.automatalife.com`).

- Check that `tls.secretName` points to a valid `TLS` secret.

### Step 3: Inspect ExternalDNS logs

```bash
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
```

Look for:

- Successful `creation` of `A` and `TXT` records.

- Conflicts or `DELETE` actions indicate misconfigured hosts or missing txtOwnerId.

### Step 4: Validate TXT Ownership

- Check that `txtOwnerId` and `domainFilters` are correctly set in:

```bash
registry/clusters/overlays/<cluster>/values.yaml
```

```yaml
txtOwnerId: frankfurt
domainFilters:
  - automatalife.com
```

-- If missing, `ExternalDNS` will fail to manage records reliably.

### Step 5: Confirm DNS in Cloudflare UI

- Navigate to `Cloudflare` DNS

- Check if:

\*\* `A` record exists for `app.<region>.automatalife.com`

\*\* Corresponding `TXT` record with `ownership` tag is present

### Step 6: Check TLS Secret Validity

```bash
kubectl get certificate -A
```

- Status should be `Ready=True`.

- Certificate must match your wildcard domain.

### Step 7: Test DNS Resolution

```bash
nslookup app.frankfurt.automatalife.com
dig +short app.frankfurt.automatalife.com
```

-- Should return your `LoadBalancer public IP`.

### Step 8: Final Live Check

```bash
curl -v https://app.frankfurt.automatalife.com
```

You should see the HTTP response from the hello-world app.
