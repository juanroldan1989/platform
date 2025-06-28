# TODO: add variables for name, description
resource "cloudflare_load_balancer" "hello_lb" {
  zone_id       = var.zone_id
  name          = "hello.automatalife.com"
  description   = "Global Load balancer for hello.automatalife.com"
  enabled       = true # Disabling a load balancer will cause it to stop routing traffic, but it will not delete the load balancer.

  default_pools = [
    cloudflare_load_balancer_pool.london.id,
    cloudflare_load_balancer_pool.frankfurt.id
  ]

  fallback_pool = cloudflare_load_balancer_pool.frankfurt.id
  proxied       = true # Proxied means that Cloudflare will handle the traffic, providing DDoS protection and caching.

  adaptive_routing = {
    failover_across_pools = true # If true, the load balancer will failover to the next pool if the current pool is unhealthy.
  }

  random_steering = { # This is a random steering policy that randomly selects a pool based on weights.
    default_weight = 0.5
    pool_weights = {
      "${cloudflare_load_balancer_pool.london.id}"    = 0.5
      "${cloudflare_load_balancer_pool.frankfurt.id}" = 0.5
    }
  }

  steering_policy = "random" # Options: random, geo, session_affinity, dynamic_latency
}

# TODO: Improvement later
# Add pools dynamically based on regions/clusters/defined within clusters/overlays and app domains

resource "cloudflare_load_balancer_pool" "london" {
  account_id = var.account_id
  name       = "london-pool"
  enabled    = true # Disabling a pool will cause any load balancers using it to failover to the next pool (if any).
  origins    = [
    {
      name    = "london-hello"
      address = "app.london.automatalife.com"
      enabled = true
    }
  ]
  monitor            = cloudflare_load_balancer_monitor.hello_monitor.id
  notification_email = var.notification_email
}

resource "cloudflare_load_balancer_pool" "frankfurt" {
  account_id = var.account_id
  name       = "frankfurt-pool"
  enabled    = true # Disabling a pool will cause any load balancers using it to failover to the next pool (if any).
  origins    = [
    {
      name    = "frankfurt-hello"
      address = "app.frankfurt.automatalife.com"
      enabled = true
    }
  ]
  monitor            = cloudflare_load_balancer_monitor.hello_monitor.id
  notification_email = var.notification_email
}

resource "cloudflare_load_balancer_monitor" "hello_monitor" {
  account_id       = var.account_id
  expected_body    = ""
  expected_codes   = "200"
  method           = "GET"
  path             = "/"
  port             = 443
  type             = "https"
  timeout          = 5
  retries          = 2
  interval         = 60 # Cloudflare "Load Balancing" subscription must be enabled. Values: [60,3600]
  follow_redirects = true
  allow_insecure   = false
}
