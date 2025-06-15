# Bootstrap `mgmt-cluster` in remove CIVO cloud

## 1 script

```ruby
➜  platform git:(main) ✗ ./scripts/bootstrap-mgmt-cluster-remote.sh

🌐 Creating Civo Kubernetes cluster: mgmt-cluster...
Merged with main kubernetes config: /Users/juanroldan/.kube/config

Access your cluster with:
kubectl get node
The cluster mgmt-cluster (7af6ec82-27aa-4057-b7f2-69f211d38690) has been created in 3 min 1 sec
✅ Cluster created and kubeconfig updated locally
🔗 Setting up kubeconfig for the new cluster...
Switched to context "mgmt-cluster".
🔐 Injecting Sealed Secrets public key...
secret/sealed-secrets-keyp26xs created
🔍 Checking AWS profile: default
✅ AWS credentials loaded from profile 'default'
🔐 Creating AWS secret for ESO (External Secrets Operator) - MGMT Cluster internal use
namespace/external-secrets created
secret/aws-creds created
🔄 Provisioning mgmt-cluster with essentials ...
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
