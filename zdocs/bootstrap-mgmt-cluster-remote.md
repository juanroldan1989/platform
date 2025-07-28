# Bootstrap `mgmt-cluster` in remove CIVO cloud

## 1 script

```ruby
platform git:(main) ./scripts/bootstrap-mgmt-cluster-remote.sh

🌍 Detecting your public IP...
📍 Your current IP is: 62.194.122.214/32
🛡️ Creating restricted firewall: mgmt-fw
Created a firewall called mgmt-fw with ID 9ce484cf-e46c-4b4c-8ea7-4bf86c922f43
Created a firewall rule to allow, ingress access to port 80 from 0.0.0.0/0 with ID 4462c4e9-f81c-482c-a68a-f6ca4bfb5b8b
Created a firewall rule to allow, ingress access to port 443 from 0.0.0.0/0 with ID 1a501445-46c5-4cc0-a012-fae9b248fd0d
Created a firewall rule to allow, ingress access to port 6443 from 62.194.122.214/32 with ID 529579cd-8e65-461f-8f5b-7ef6cd6cc934
Created a firewall rule to allow, egress access to ports 1-65535 to 0.0.0.0/0 with ID f6df08d6-6628-43d9-b223-fba0773d7ead
🧹 Cleaning up insecure default ingress rules added by Civo...
🚫 Deleting insecure rule ID: 8fd6543c-2d46-4e07-a464-b941792626e8
The firewall rule (All TCP ports open) has been deleted
🚫 Deleting insecure rule ID: 8e412915-b102-447f-ae64-92471e1c2a22
The firewall rule (All UDP ports open) has been deleted
🚫 Deleting insecure rule ID: f501e75c-72b1-4109-9a86-da1368887525
The firewall rule (Ping/traceroute) has been deleted
✅ Finished removing default insecure firewall rules.
✅ Firewall rules cleaned up. Cluster access is now restricted to intended sources.
🚀 Creating Civo Kubernetes cluster: mgmt...
Merged with main kubernetes config: /Users/juanroldan/.kube/config

Access your cluster with:
kubectl get node
The cluster mgmt (2194fe88-2335-412e-aa5f-a4fae26944b0) has been created in 1 min 58 sec
✅ Cluster created and kubeconfig updated locally
🔗 Setting up kubeconfig for the new cluster...
Switched to context "mgmt".
🔐 Injecting Sealed Secrets public key...
secret/sealed-secrets-keyp26xs created
🔍 Checking AWS profile: default
✅ AWS credentials loaded from profile 'default'
🔐 Creating AWS secret for ESO (External Secrets Operator) - MGMT Cluster internal use
namespace/external-secrets created
secret/aws-creds created
🔄 Provisioning management cluster with essentials ...
namespace/argocd created
serviceaccount/argocd-bootstrap created
clusterrolebinding.rbac.authorization.k8s.io/argocd-bootstrap-admin created
job.batch/argocd-bootstrap-installer created
job.batch/argocd-app-bootstrap created
✅ Bootstrap completed. ArgoCD should self-manage itself shortly.
```

## After `3 min 1 sec` approx

We can access ArgoCD Server with:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

```bash
kubectl -n argocd port-forward svc/argocd-server 8888:80
```

## `App of Apps` ArgoCD Pattern takes care of

1. Provisioning tools within `mgmt` cluster:

- Crossplane
- Crossplane Terraform Provider
- NGINX Ingress
- ESO (External Secrets Operator)
- Cert Manager
- External DNS Operator

2. Provisioning `workload` clusters:

- `london` cluster in `CIVO` Cloud.
- `newyork` cluster in `Vultr` Cloud.

3. Provisioning tools in `workload` clusters:

- NGINX Ingress
- ESO (External Secrets Operator)
- Cert Manager
- External DNS Operator

4. Deploy applications into `workload` clusters:

- `hello-world` application with: NGINX Ingress, DNS records (Cloudflare) and TLS certificates (secure SSL access).

5. Defines NGINX Ingress secure access to ArgoCD Server through `argocd.automatalife.com`.

- No need to port-forward into argocd-server afterwards.
