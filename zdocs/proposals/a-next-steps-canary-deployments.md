# How Argo Rollouts Works With Your Stack

The Argo Rollouts controller extends Kubernetes with a Rollout resource that replaces Deployment. For canary with weight-based traffic splitting via nginx, it needs:

- A stable Service — receives production traffic
- A canary Service — receives the percentage weight during rollout
- The Rollout controller automatically creates a mirror ingress and manipulates nginx canary-weight annotations behind the scenes — you don't manage that manually

## File 1: Install the Argo Rollouts controller on workload clusters

New file at argo/tools/argo-rollouts.yaml:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: argo-rollouts
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "50"
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            workload: "true"
  template:
    metadata:
      name: argo-rollouts-{{name}}
      annotations:
        argocd.argoproj.io/description: "Deploy Argo Rollouts controller in {{name}} cluster"
    spec:
      project: default
      source:
        repoURL: https://argoproj.github.io/argo-helm
        chart: argo-rollouts
        targetRevision: 2.38.0
        helm:
          parameters:
            - name: installCRDs
              value: "true"
            - name: dashboard.enabled
              value: "true"
      destination:
        name: '{{name}}'
        namespace: argo-rollouts
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

This follows the exact same pattern as your existing cert-manager.yaml, eso-config.yaml etc. — no structural change to the repo.

## File 2: Updated hello-world template

Replace hello-world.yaml entirely:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hello-{{ .Values.global.name }}
---
# Stable service — receives 100% of traffic during normal operation
apiVersion: v1
kind: Service
metadata:
  name: hello-{{ .Values.global.name }}-stable
  namespace: hello-{{ .Values.global.name }}
spec:
  selector:
    app: hello
  ports:
    - port: 80
      targetPort: 5678
---
# Canary service — receives the shifting weight during a rollout
apiVersion: v1
kind: Service
metadata:
  name: hello-{{ .Values.global.name }}-canary
  namespace: hello-{{ .Values.global.name }}
spec:
  selector:
    app: hello
  ports:
    - port: 80
      targetPort: 5678
---
# Rollout replaces Deployment — same pod spec, adds canary strategy
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: hello-{{ .Values.global.name }}
  namespace: hello-{{ .Values.global.name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: hello
          image: hashicorp/http-echo
          args:
            - "-text=👋 Hello from {{ .Values.global.name }}.automatalife.com"
          ports:
            - containerPort: 5678
  strategy:
    canary:
      stableService: hello-{{ .Values.global.name }}-stable
      canaryService: hello-{{ .Values.global.name }}-canary
      trafficRouting:
        nginx:
          stableIngress: hello-ingress-{{ .Values.global.name }}
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 10m}
        - setWeight: 100
---
# Ingress points to stable service only — Rollout controller manages canary routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-ingress-{{ .Values.global.name }}
  namespace: hello-{{ .Values.global.name }}
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts:
        - hello.{{ .Values.global.name }}.automatalife.com
        - hello.automatalife.com
      secretName: wildcard-tls
  rules:
    - host: hello.{{ .Values.global.name }}.automatalife.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-{{ .Values.global.name }}-stable
                port:
                  number: 80
    - host: hello.automatalife.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-{{ .Values.global.name }}-stable
                port:
                  number: 80
```

## What happens when you push a new image

ArgoCD detects image change → triggers Rollout
  → 10% traffic to canary pods (new image)
  → waits 5 minutes
  → 50% traffic to canary pods
  → waits 10 minutes
  → 100% → canary becomes new stable → rollout complete

----

If anything fails mid-rollout, kubectl argo rollouts abort hello-london immediately routes 100% back to stable.