resource "cloudflare_load_balancer" "hello_lb" {
  zone_id          = var.cloudflare_zone_id
  name             = "hello.automatalife.com"
  fallback_pool_id = cloudflare_load_balancer_pool.frankfurt.id
  default_pools    = [cloudflare_load_balancer_pool.london.id, cloudflare_load_balancer_pool.frankfurt.id]
  proxied          = true
}

resource "cloudflare_load_balancer_pool" "london" {
  name = "london-pool"
  origins {
    name    = "london-hello"
    address = "app.london.automatalife.com"
    enabled = true
  }
  monitor = cloudflare_load_balancer_monitor.hello_monitor.id
}

resource "cloudflare_load_balancer_pool" "frankfurt" {
  name = "frankfurt-pool"
  origins {
    name    = "frankfurt-hello"
    address = "app.frankfurt.automatalife.com"
    enabled = true
  }
  monitor = cloudflare_load_balancer_monitor.hello_monitor.id
}

resource "cloudflare_load_balancer_monitor" "hello_monitor" {
  expected_body    = ""
  expected_codes   = "200"
  method           = "GET"
  path             = "/"
  port             = 443
  type             = "https"
  timeout          = 5
  retries          = 2
  interval         = 60
  follow_redirects = true
  allow_insecure   = false
}
