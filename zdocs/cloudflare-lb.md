# Global Server Load Balancing (GSLB)

Global Server Load Balancing (GSLB) is a traffic distribution technique that:

- Intelligently routes user requests across multiple geographically dispersed servers or data centers.

The goal is to improve performance, resilience and availability by directing traffic to **the most optimal location.**

- Cloudflare’s Load Balancing solution implements `GSLB` by leveraging its global network of edge data centers.

It evaluates multiple real-time factors such as:

✅ Server health – Ensures traffic is only sent to healthy and responsive servers.

📍 Geographic proximity – Routes users to the nearest available region to minimize latency.

⚡ Performance metrics – Takes into account response time and throughput to select the best target.

## Cloudflare as a Global Load Balancer

Cloudflare’s load balancers are inherently global. They:

- Operate across a worldwide Anycast network, enabling ultra-low latency routing decisions.

- Continuously monitor origin pools and automatically fail over if a server or region becomes unavailable.

- Support geo-routing, latency-based routing, and failover strategies to keep applications fast and reliable.

## Benefits of Cloudflare GSLB:

- Improved performance by reducing round-trip time.

- Increased availability through intelligent failover.

- Scalability by spreading load across multiple origins.

- Reduced downtime and enhanced user experience globally.

# Cloudflare `GLB` for `hello.automatalife.com`

This document explains the setup of a **Cloudflare Global Load Balancer** that routes external traffic to:

```
https://hello.automatalife.com
```

This load balancer distributes requests across regionally deployed instances of a `Hello World` application, hosted in separate Kubernetes clusters:

* [`https://app.london.automatalife.com`](https://app.london.automatalife.com) -> CIVO cloud provider (`london` region)
* [`https://app.frankfurt.automatalife.com`](https://app.frankfurt.automatalife.com) -> CIVO cloud provider (`frankfurt` region)

## Goals

* Provide **high availability** and **geographically distributed failover**
* Detect failures via **health checks** and **automatic failover**
* Route external requests to `hello.automatalife.com` across multiple Kubernetes clusters (`london`, `frankfurt`, etc.) and cloud providers (`CIVO`, `Vultr`, `Heztner`)
* Ensure **TLS validation and HTTPS health checks** via Cloudflare’s Load Balancing monitor
* Make the setup fully **GitOps-compliant** using **Terraform** and **ArgoCD**

## Infrastructure Components

| Component                          | Description                                                                                        |
| ---------------------------------- | -------------------------------------------------------------------------------------------------- |
| `cloudflare_load_balancer_monitor` | Performs HTTPS GET health checks to `/` on each backend origin                                     |
| `cloudflare_load_balancer_pool`    | Maps to each cluster’s ingress subdomain (e.g. `app.london.automatalife.com`)                      |
| `cloudflare_load_balancer`         | Exposes the main entrypoint at `hello.automatalife.com` and performs steering                      |
| Kubernetes `Ingress` resources     | Serve traffic in each cluster, with support for both local and global hostnames                    |
| TLS Certificates (`cert-manager`)  | Wildcard certificates valid for both `app.<cluster>.automatalife.com` and `hello.automatalife.com` |

## Cloudflare API Token Configuration

To enable Terraform-based provisioning of monitors, pools, and load balancers via the Cloudflare API,

a properly scoped **User API Token** is required.

This token must have permissions that span both the account and the specific DNS zone (`automatalife.com`).

Below is a working configuration:

### User API Token Permissions

#### Account-wide Permissions:

- `Load Balancing: Account Load Balancers` – **Read & Edit**
- `Load Balancing: Monitors and Pools` – **Read & Edit**

#### Zone-specific Permissions (for `automatalife.com`):

- `Zone` – **Read & Edit**
- `DNS` – **Read & Edit**
- `Load Balancers` – **Read & Edit**

### Token Scope

- **Account access**: Set to `All accounts`
- **Zone access**: Scoped to `automatalife.com`

- **Note**: These permissions are required because:

> - Terraform needs to manage Load Balancer resources across the account (monitors & pools).

> - Load Balancers are linked to a specific DNS zone and require zone-level edit permissions to create the `hello.automatalife.com` record.

> - `External-DNS` and `cert-manager` (using the same token or a separate one) also require `DNS:Edit` for automated DNS management and TLS provisioning.

### Additional Tips

- **Token Location in Terraform**: Store the token in a Kubernetes `Secret` and reference it via `TF_VAR_cloudflare_api_token` (`registry/load_balancers/provision/templates/provider-config.yaml`).

- **Avoid IP Restrictions** during early development unless you're using static IP GitOps runners.

## Key Fixes and Required Setup

### 1. Enable Cloudflare Load Balancing Subscription

A paid **Cloudflare Load Balancing plan** is required to provision load balancers and configure health checks via the API.

* Go to **Cloudflare Dashboard → Load Balancing → Enable Subscription**
* Choose Basic Plan (\$5/month), which includes 2 endpoint checks

### 2. Create Wildcard TLS Certificates per Cluster

Each cluster must have a valid `cert-manager`-managed wildcard `TLS` certificate within `Certificate` Kubernetes `cert-manager.io/v1` resource:

```yaml
spec:
  secretName: wildcard-tls
  dnsNames:
    - "*.frankfurt.automatalife.com"
```

- And deploy that `certificate` to all relevant app namespaces (e.g.: `hello-frankfurt`, `blog-frankfurt`, etc) where applications's ingress exist.

- Each application `Ingress` uses the **shared secret wildcard-tls** (copied to each namespace), and this works because:

-- The Ingress for each app points to `app.<cluster>.automatalife.com`

-- The `cert-manager`-managed wildcard cert correctly matches that hostname

-- **Cloudflare's Load Balancer** only checks the specific domains (e.g.: `app.london.automatalife.com`, not `hello.automatalife.com` directly)

### 3. Ingress `Host` and `TLS` Configuration

Your application's `Ingress` resource must support **both** the local and global domains:

```yaml
spec:
  tls:
    - hosts:
        - app.<cluster-name>.automatalife.com
        - hello.automatalife.com
      secretName: wildcard-tls
  rules:
    - host: app.<cluster-name>.automatalife.com
      http:
        paths:
          ...
    - host: hello.automatalife.com
      http:
        paths:
          ...
```

- This resolves the issue where Cloudflare forwards a request using the `hello.automatalife.com` `Host` header, which would otherwise result in an NGINX `404 Not Found`.

- Your Ingress definitions needed to:

-- Match the exact `FQDN` (e.g.: `app.london.automatalife.com`)

-- Have the `kubernetes.io/ingress.class: nginx` annotation

-- Use the correct **TLS** secret reference (as above)

### 4. Confirm Monitor Health

Once `TLS` and routing are correctly configured, the Cloudflare monitor (via `GET /`) will report both pools as **healthy**

and the **Global Load Balancer** will begin forwarding traffic as expected.

## Result

Load Balancer configuration is **fully declarative and GitOps-managed**

After syncing all corrections:

- Both `Cloudflare LB pools` became **healthy**

- **Global Load Balancer** (`hello.automatalife.com`) began routing requests randomly to the healthy origins

- Requests hit either the `Frankfurt` or `London` **Hello app**:

```
👋 Hello from london.automatalife.com
```

```
👋 Hello from frankfurt.automatalife.com
```

## File Structure & Paths

| Path                                  | Description                                                                |
| ------------------------------------- | -------------------------------------------------------------------------- |
| `terraform/modules/cloudflare_lb/`    | Reusable `Terraform` module for `Cloudflare Load Balancer` setup           |
| `registry/clusters/overlays/<region>` | Region-specific `Helm` values, including `TLS` domains and `ingress` rules |
| `workload/apps/hello-world.yaml`      | Template manifest for multi-cluster Hello World app                        |
| `cloudflare-lb.md`                    | (This file) Implementation details and operational expectations            |

## Deployment Flow

1. Create a new cluster (`london`, `frankfurt`, etc.) in `registry/clusters/overlays/<cluster-name>`

- New Cluster will be provisioned by `argo/clusters/provision.yaml` ArgoCD app.

2. Deploy the `Hello World` app to the cluster via `ArgoCD` and `Helm` -> `argo/apps/<app-name>.yaml`
3. Ensure the `Ingress` is configured with both:

   * `app.<region>.automatalife.com`
   * `hello.automatalife.com`

4. Ensure `cert-manager` issues a wildcard cert for both domains
5. Add the new origin to the appropriate `cloudflare_load_balancer_pool`
6. ArgoCD syncs the Terraform-based workspace and updates the Cloudflare config

## Traffic Example

| Request                           | Outcome                                           |
| --------------------------------- | ------------------------------------------------- |
| `https://hello.automatalife.com`  | Routed to one of the regional clusters            |
| Request 1                         | Serves `👋 Hello from london.automatalife.com`    |
| Request 2 (new session/incognito) | Serves `👋 Hello from frankfurt.automatalife.com` |
