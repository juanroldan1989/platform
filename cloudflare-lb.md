# Cloudflare Load Balancer: `hello.automatalife.com`

This document explains how we route traffic to:

`https://hello.automatalife.com`

using **Cloudflare Load Balancing** for `HA` and `geo-distribution`.

## Goals

- Route traffic to **multiple Kubernetes clusters** (e.g.: `london`, `frankfurt`)
- Detect failures via health checks and **failover automatically**
- Integrate this setup into **GitOps workflows and Terraform**

## Infrastructure Components

- **cloudflare_load_balancer_monitor**: Checks `/` over HTTPS
- **cloudflare_load_balancer_pool**: Points to each cluster’s `app.<region>.automatalife.com`
- **cloudflare_load_balancer**: Connects DNS name `hello.automatalife.com` with pools

## Files and Paths

| File                                         | Purpose                                               |
| -------------------------------------------- | ----------------------------------------------------- |
| `terraform/modules/cloudflare_loadbalancer/` | Contains the reusable Terraform module                |
| `cloudflare-lb.md`                           | (This file) documents reasoning and healthcheck logic |

## Deployment Process

1. Add new cluster endpoint to the `default_pools` list
2. Commit to Git
3. ArgoCD syncs changes
4. Cloudflare LB auto-adjusts routing logic

> 💡 DNS record for `hello.automatalife.com` is **created by the Load Balancer** automatically.
