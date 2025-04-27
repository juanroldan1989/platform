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
docker ps

CONTAINER ID   IMAGE                                COMMAND                  CREATED              STATUS              PORTS                                              NAMES
839462831ee2   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   59 seconds ago       Up 58 seconds                                                          test-cluster-md-0-8lcth-c4ggb
4f9b3250ef14   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up 58 seconds                                                          prod-cluster-md-0-7drpc-98gdt
06f026194fbe   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up 58 seconds                                                          dev-cluster-md-0-whz8f-tn99c
41c2416c4a21   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up About a minute   127.0.0.1:55019->6443/tcp                          test-cluster-control-plane-bsvhg
0240ae86faca   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up About a minute   127.0.0.1:55020->6443/tcp                          prod-cluster-control-plane-fshm4
0c917ecbc788   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up About a minute   127.0.0.1:55018->6443/tcp                          dev-cluster-control-plane-vqw2t
a485990bfe8d   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   About a minute ago   Up About a minute   0.0.0.0:55016->6443/tcp, 0.0.0.0:55017->8404/tcp   test-cluster-lb
5c8584e87fb8   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   About a minute ago   Up About a minute   0.0.0.0:55014->6443/tcp, 0.0.0.0:55015->8404/tcp   prod-cluster-lb
07f7cb444b5d   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   About a minute ago   Up About a minute   0.0.0.0:55012->6443/tcp, 0.0.0.0:55013->8404/tcp   dev-cluster-lb
83054fa7389a   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   5 minutes ago        Up 5 minutes        127.0.0.1:64899->6443/tcp                          mgmt-cluster-control-plane

---

docker ps

CONTAINER ID   IMAGE                                COMMAND                  CREATED              STATUS              PORTS                                              NAMES
839462831ee2   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up About a minute                                                      test-cluster-md-0-8lcth-c4ggb
4f9b3250ef14   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up About a minute                                                      prod-cluster-md-0-7drpc-98gdt
06f026194fbe   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   About a minute ago   Up About a minute                                                      dev-cluster-md-0-whz8f-tn99c
41c2416c4a21   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   2 minutes ago        Up 2 minutes        127.0.0.1:55019->6443/tcp                          test-cluster-control-plane-bsvhg
0240ae86faca   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   2 minutes ago        Up 2 minutes        127.0.0.1:55020->6443/tcp                          prod-cluster-control-plane-fshm4
0c917ecbc788   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   2 minutes ago        Up 2 minutes        127.0.0.1:55018->6443/tcp                          dev-cluster-control-plane-vqw2t
a485990bfe8d   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   2 minutes ago        Up 2 minutes        0.0.0.0:55016->6443/tcp, 0.0.0.0:55017->8404/tcp   test-cluster-lb
5c8584e87fb8   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   2 minutes ago        Up 2 minutes        0.0.0.0:55014->6443/tcp, 0.0.0.0:55015->8404/tcp   prod-cluster-lb
07f7cb444b5d   kindest/haproxy:v20230606-42a2262b   "haproxy -W -db -f /…"   2 minutes ago        Up 2 minutes        0.0.0.0:55012->6443/tcp, 0.0.0.0:55013->8404/tcp   dev-cluster-lb
83054fa7389a   kindest/node:v1.32.2                 "/usr/local/bin/entr…"   5 minutes ago        Up 5 minutes        127.0.0.1:64899->6443/tcp                          mgmt-cluster-control-plane

---

kubectl get machinedeployments -A

NAMESPACE   NAME                CLUSTER        REPLICAS   READY   UPDATED   UNAVAILABLE   PHASE     AGE     VERSION
default     dev-cluster-md-0    dev-cluster    1          1       1         0             Running   2m32s   v1.32.2
default     prod-cluster-md-0   prod-cluster   1          1       1         0             Running   2m32s   v1.32.2
default     test-cluster-md-0   test-cluster   1          1       1         0             Running   2m32s   v1.32.2
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

root@mgmt-cluster-control-plane:/# kubectl get nodes
NAME                         STATUS   ROLES           AGE   VERSION
mgmt-cluster-control-plane   Ready    control-plane   12m   v1.32.2

root@mgmt-cluster-control-plane:/# export KUBECONFIG=/etc/kubernetes/dev-cluster.kubeconfig

root@mgmt-cluster-control-plane:/# kubectl get nodes
NAME                              STATUS   ROLES           AGE     VERSION
dev-cluster-control-plane-vqw2t   Ready    control-plane   9m20s   v1.32.2
dev-cluster-md-0-whz8f-tn99c      Ready    <none>          8m56s   v1.32.2

root@mgmt-cluster-control-plane:/# kubectl get svc -A
NAMESPACE     NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
default       kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP                  9m25s
kube-system   kube-dns     ClusterIP   10.96.0.10     <none>        53/UDP,53/TCP,9153/TCP   9m21s
name-app      name         ClusterIP   10.96.81.128   <none>        5001/TCP                 5m49s

root@mgmt-cluster-control-plane:/# kubectl get deploy -A
NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   calico-kube-controllers   1/1     1            1           9m14s
kube-system   coredns                   2/2     2            2           9m28s
name-app      name-deployment           1/1     1            1           5m56s
```

## Deploying Applications into Workload Clusters

- Name App:

```bash
kubectl apply -f argocd-configuration/name-app-appset.yaml -n argocd
```

### ArgoCD UI - Applications across clusters

<img width="1359" alt="Screenshot 2025-04-27 at 11 46 23" src="https://github.com/user-attachments/assets/76790d21-5e38-4762-ad6f-32c7cea6f7cf" />

### ArgoCD UI - Name App (DEV Cluster)

<img width="1360" alt="Screenshot 2025-04-27 at 11 46 35" src="https://github.com/user-attachments/assets/96c468d3-09dd-494d-8a0f-20e8a203cd37" />

### ArgoCD UI - Name App (TEST Cluster)

<img width="1359" alt="Screenshot 2025-04-27 at 11 46 56" src="https://github.com/user-attachments/assets/943edb9d-4ab5-4507-99ac-83c8af867784" />

### ArgoCD UI - Name App (PROD Cluster)

<img width="1350" alt="Screenshot 2025-04-27 at 11 46 45" src="https://github.com/user-attachments/assets/33cdf5ca-eb14-456c-aef5-5833fa602c45" />
