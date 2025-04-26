# Bootstrap

## Provision MGMT Cluster

- This cluster is the management access to itself and all the others clusters.

- For queries, updates or even removals of resources on dev/test/prod clusters, connect to this cluster.

```bash
./bootstrap/bootstrap-mgmt-cluster.sh
```

- Get `ArgoCD` server IP address for `registering clusters` step:

```bash
kubectl get svc -A
NAMESPACE NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
argocd    argocd-server     ClusterIP   10.96.17.204    <none>        80/TCP,443/TCP           118s
```

## Provision Workload Clusters

Each `workload` cluster (dev/test/prod) is provisioned with:

- 1 Controlplane
- 1 Worker Node

```bash
./bootstrap/bootstrap-workload-clusters.sh
```

- Inspecting machines, machine deployments and containers:

```bash
kubectl get machinedeployments -A
                                                                                                                                             in 0.056s (0)
NAMESPACE   NAME                CLUSTER        REPLICAS   READY   UPDATED   UNAVAILABLE   PHASE       AGE   VERSION
default     dev-cluster-md-0    dev-cluster    1                  1         1             ScalingUp   27m   v1.32.2
default     prod-cluster-md-0   prod-cluster   1                  1         1             ScalingUp   27m   v1.32.2
default     test-cluster-md-0   test-cluster   1                  1         1             ScalingUp   27m   v1.32.2

----

docker ps
                                                                                                                                                                                                       in 0.082s (0)
CONTAINER ID   IMAGE                                COMMAND                  CREATED          STATUS          PORTS                                              NAMES
d12c283039a9   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   27 minutes ago   Up 27 minutes                                                      prod-cluster-md-0-5bgp7-wxjvx
df62291590ea   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   27 minutes ago   Up 27 minutes                                                      test-cluster-md-0-zx5nt-ftl7r
e9ff34f82fc2   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   27 minutes ago   Up 27 minutes                                                      dev-cluster-md-0-8vh7l-hlt7b
50877e5dc865   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   27 minutes ago   Up 27 minutes   127.0.0.1:55053->6443/tcp                          test-cluster-control-plane-sgzr7
160797ae10a5   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   27 minutes ago   Up 27 minutes   127.0.0.1:55052->6443/tcp                          prod-cluster-control-plane-vzwxv
71606fffc779   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   27 minutes ago   Up 27 minutes   127.0.0.1:55051->6443/tcp                          dev-cluster-control-plane-fsgrs
4d09067eca0d   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   27 minutes ago   Up 27 minutes   0.0.0.0:55067->6443/tcp, 0.0.0.0:55068->8404/tcp   test-cluster-lb
b325c704bb8c   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   27 minutes ago   Up 27 minutes   0.0.0.0:55065->6443/tcp, 0.0.0.0:55066->8404/tcp   prod-cluster-lb
076c0e2eff12   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   27 minutes ago   Up 27 minutes   0.0.0.0:55063->6443/tcp, 0.0.0.0:55064->8404/tcp   dev-cluster-lb
9951c50018c7   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   31 minutes ago   Up 31 minutes   127.0.0.1:65040->6443/tcp                          mgmt-cluster-control-plane

----

kubectl get machines -A -o wide
                                                                                                                                                                                                       in 0.071s (0)
NAMESPACE   NAME                               CLUSTER        NODENAME                           PROVIDERID                                    PHASE          AGE   VERSION
default     dev-cluster-control-plane-fsgrs    dev-cluster    dev-cluster-control-plane-fsgrs    docker:////dev-cluster-control-plane-fsgrs    Running        28m   v1.32.2
default     dev-cluster-md-0-8vh7l-hlt7b       dev-cluster                                                                                     Provisioning   27m   v1.32.2
default     prod-cluster-control-plane-vzwxv   prod-cluster   prod-cluster-control-plane-vzwxv   docker:////prod-cluster-control-plane-vzwxv   Running        28m   v1.32.2
default     prod-cluster-md-0-5bgp7-wxjvx      prod-cluster                                                                                    Provisioning   27m   v1.32.2
default     test-cluster-control-plane-sgzr7   test-cluster   test-cluster-control-plane-sgzr7   docker:////test-cluster-control-plane-sgzr7   Running        28m   v1.32.2
default     test-cluster-md-0-zx5nt-ftl7r      test-cluster                                                                                    Provisioning   27m   v1.32.2
```

## Register Workload Clusters into MGMT Cluster

- This way ArgoCD is able to connect to `workload` clusters (dev/test/prod) and deploy applications into them:

- Replace `MGMT_CONTAINER_ARGOCD_SERVER` in script with `ArgoCD` server IP.

```bash
./bootstrap/register-workload-clusters.sh
```

- Afterwards, all clusters should be registered to `ArgoCD` in `mgmt-cluster` and labeled properly:

```bash
$ kubectl get clusters --show-labels

NAME           CLUSTERCLASS   PHASE         AGE   VERSION   LABELS
dev-cluster                   Provisioned   32m             environment=dev,workload-deploy=enabled
prod-cluster                  Provisioned   32m             environment=prod,workload-deploy=enabled
test-cluster                  Provisioned   32m             environment=test,workload-deploy=enabled
```

Labels help to specify clusters when deploying applications later, to avoid relying on clusters IP addresses.

## Access Workload Cluster from MGMT Cluster

```bash
docker exec -it mgmt-cluster-control-plane bash

# clusters .kubeconfig files copied on this folder
# since this is a persistent folder in `kind` clusters (`/tmp` folder for regular clusters)
root@mgmt-cluster-control-plane:/# cd /etc/kubernetes

root@mgmt-cluster-control-plane:/etc/kubernetes# ls
admin.conf		 dev-cluster.kubeconfig  manifests  prod-cluster.kubeconfig  super-admin.conf
controller-manager.conf  kubelet.conf		 pki	    scheduler.conf	     test-cluster.kubeconfig

root@mgmt-cluster-control-plane:~# export KUBECONFIG=/etc/kubernetes/dev-cluster.kubeconfig

root@mgmt-cluster-control-plane:~# kubectl config get-contexts
CURRENT   NAME                            CLUSTER       AUTHINFO            NAMESPACE
*         dev-cluster-admin@dev-cluster   dev-cluster   dev-cluster-admin

root@mgmt-cluster-control-plane:~# kubectl config use-context dev-cluster-admin@dev-cluster

Switched to context "dev-cluster-admin@dev-cluster".

root@mgmt-cluster-control-plane:~# kubectl get nodes
NAME                              STATUS     ROLES           AGE   VERSION
dev-cluster-control-plane-cmf5j   Ready      control-plane   35m   v1.32.2
```

## Deploying Applications into Workload Clusters

- Name App:

```bash
kubectl apply -f argocd-configuration/name-app-appset.yaml -n argocd
```
