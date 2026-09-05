---
title: "Ignition — First Kubernetes Cluster"
description: "Create a kind cluster, run one Pod, and learn a reusable Kubernetes troubleshooting loop."
---

# Ignition — First Kubernetes Cluster

**Goal:** Create a local Kubernetes cluster, run one HTTP Pod, and prove what
Kubernetes does—and does not—recover automatically.

Ignition deliberately uses one small workload. The point is to learn the
control loop and an evidence-first debugging routine before Apollo Airlines
adds Deployments, Services, configuration, and databases in Stage 1.

## What you will learn

- how a kind cluster maps Kubernetes nodes to Docker containers;
- what the API server, etcd, scheduler, controller manager, kubelet, CoreDNS,
  kube-proxy, and kindnet each contribute;
- how imperative and declarative workflows differ;
- how to inspect status, events, `describe` output, logs, and application
  behavior in a repeatable order;
- how the kubelet restarts a failed container inside an existing Pod; and
- why deleting a bare Pod requires a person to recreate it, while Stage 1's
  Deployment controller can replace it automatically.

## Prerequisites

You need Docker, kind, kubectl, and curl. Confirm that Docker is running:

```bash
docker info >/dev/null
kind version
kubectl version --client
curl --version
```

Run the remaining commands from the repository root.

## Build

### 1. Create the cluster

The recommended cluster has one control-plane and two worker nodes, matching
the topology used by later local stages:

```bash
kind create cluster --config stages/ignition/kind-config.yaml
kubectl config current-context
kubectl get nodes -o wide
```

The context must be `kind-apollo11`, and all three nodes must become `Ready`.
For a smaller machine, use the single-node alternative instead:

```bash
kind create cluster --config stages/ignition/kind-config-single.yaml
```

That cluster's context is `kind-apollo11-dev`. Do not create both cluster
variants at the same time: their later-stage host port mappings intentionally
overlap.

kind runs each Kubernetes node as a Docker container. Compare both views:

```bash
docker ps --filter label=io.x-k8s.kind.cluster=apollo11
kubectl get nodes
```

### 2. Discover the cluster

```bash
kubectl cluster-info
kubectl get namespaces
kubectl get pods -n kube-system -o wide
kubectl api-resources
```

The control plane stores desired state and makes placement decisions. The
kubelet on the chosen node asks the container runtime to keep this Pod's
container running. CoreDNS provides in-cluster name resolution, kindnet is the
default CNI, and kube-proxy implements Service forwarding. NetworkPolicy
enforcement is intentionally deferred until Stage 8 because kindnet does not
enforce it.

```text
kubectl
   |
   v
API server <--> etcd
   |             desired and observed state
   +--> scheduler / controller manager
   |
   +--> kubelet on node --> container runtime --> Pod
```

### 3. Create the first Pod imperatively

Start with an imperative command and ask kubectl to show the object it would
send to the API server:

```bash
kubectl run apollo-shell \
  --image=busybox:1.36.1 \
  --restart=Always \
  --labels=app=shell,stage=ignition \
  --port=8080 \
  --dry-run=client -o yaml \
  -- sh -c 'mkdir -p /www; printf "Apollo11 Ignition ready\n" > /www/index.html; echo "ignition HTTP server started"; httpd -f -p 8080 -h /www & server_pid=$!; wait "$server_pid"'
```

Now run the same command without `--dry-run=client -o yaml`:

```bash
kubectl run apollo-shell \
  --image=busybox:1.36.1 \
  --restart=Always \
  --labels=app=shell,stage=ignition \
  --port=8080 \
  -- sh -c 'mkdir -p /www; printf "Apollo11 Ignition ready\n" > /www/index.html; echo "ignition HTTP server started"; httpd -f -p 8080 -h /www & server_pid=$!; wait "$server_pid"'
kubectl wait --for=condition=Ready pod/apollo-shell --timeout=90s
```

### 4. Move to a declarative manifest

Delete the imperative object, inspect the committed manifest, and apply it:

```bash
kubectl delete pod apollo-shell
kubectl apply --dry-run=client -f stages/ignition/pod.yaml
kubectl apply -f stages/ignition/pod.yaml
kubectl wait --for=condition=Ready pod/apollo-shell --timeout=90s
```

`kubectl apply` records a desired object that can be reviewed and applied
again. It does not, by itself, create a controller for a bare Pod.

## Inspect: the evidence ladder

Use this order whenever a Kubernetes workload is unhealthy. Stop as soon as
one layer explains the problem.

| Evidence | Command | Question it answers |
|---|---|---|
| Status | `kubectl get pod apollo-shell -o wide` | Is it Pending, Running, or failing? Where was it placed? |
| Events | `kubectl get events --field-selector involvedObject.name=apollo-shell --sort-by=.metadata.creationTimestamp` | What decisions and failures occurred over time? |
| Detail | `kubectl describe pod apollo-shell` | Which image, command, conditions, and recent events explain the status? |
| Logs | `kubectl logs apollo-shell` | What did the process report? |
| Behavior | port-forward plus `curl` | Can a user obtain the expected response? |

Run every rung once for the healthy Pod:

```bash
kubectl get pod apollo-shell -o wide
kubectl get events \
  --field-selector involvedObject.name=apollo-shell \
  --sort-by=.metadata.creationTimestamp
kubectl describe pod apollo-shell
kubectl logs apollo-shell
```

In a second terminal, forward a local port directly to the Pod:

```bash
kubectl port-forward pod/apollo-shell 18080:8080
```

Back in the first terminal, prove behavior rather than merely trusting
`Running`:

```bash
curl --fail http://127.0.0.1:18080/
```

Expected response:

```text
Apollo11 Ignition ready
```

Stop the port-forward with Ctrl-C after the check.

## Break 1: crash the container

Capture identity and restart state, then terminate the HTTP server process. The
container's supervising shell exits when that child process fails:

```bash
kubectl get pod apollo-shell \
  -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,RESTARTS:.status.containerStatuses[0].restartCount'
kubectl exec apollo-shell -- sh -c 'kill "$(pidof httpd)"' || true
```

The exec connection may close with an error because it deliberately kills the
container. Watch recovery, then rerun the evidence ladder:

```bash
kubectl get pod apollo-shell --watch
# Press Ctrl-C after the Pod returns to 1/1 Running.
kubectl get pod apollo-shell \
  -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,RESTARTS:.status.containerStatuses[0].restartCount'
kubectl logs apollo-shell --previous
kubectl describe pod apollo-shell
kubectl exec apollo-shell -- wget -qO- http://127.0.0.1:8080/
```

The Pod UID stays the same and `RESTARTS` increases. The kubelet honored the
Pod's `restartPolicy: Always` by restarting its container. The final HTTP
response proves behavioral recovery.

## Break 2: delete the bare Pod

Now remove the Kubernetes object itself:

```bash
kubectl get pod apollo-shell -o jsonpath='{.metadata.uid}{"\n"}'
kubectl delete pod apollo-shell --wait=true
sleep 3
kubectl get pod apollo-shell
```

The final command must report `NotFound`. No controller owns this bare Pod, so
nothing replaces it. This is the limitation Stage 1 solves with a Deployment
and ReplicaSet.

## Recover

Reapply the declared state and capture the new identity:

```bash
kubectl apply -f stages/ignition/pod.yaml
kubectl wait --for=condition=Ready pod/apollo-shell --timeout=90s
kubectl get pod apollo-shell \
  -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,RESTARTS:.status.containerStatuses[0].restartCount'
kubectl exec apollo-shell -- wget -qO- http://127.0.0.1:8080/
```

The recovered Pod has a new UID and returns `Apollo11 Ignition ready`. That is
observable recovery; the existence of a new object alone would not prove the
application works.

## Maintainer verification

The verifier repeats the crash, deletion, and recovery checks against the
current kind context. It only accepts the two learner contexts documented by
this lab (plus the reserved maintainer lifecycle-test context) and leaves one
healthy `apollo-shell` Pod behind for inspection.

```bash
bash stages/ignition/scripts/verify.sh
```

## Clean up and audit residue

Delete the workload, then delete the exact cluster variant you created:

```bash
kubectl delete -f stages/ignition/pod.yaml --ignore-not-found
kind delete cluster --name apollo11
kind get clusters
kubectl config get-contexts -o name
```

For the single-node alternative, substitute `apollo11-dev`. The deleted name
must be absent from both final listings. Other clusters and contexts are not
Ignition residue and must not be deleted.

## Explain

You should now be able to answer:

1. Why can a Pod be `Running` while the application is still unusable?
2. Which evidence rung would you inspect first, and when would you move down
   the ladder?
3. Why did killing the application process increase the restart count without
   changing the Pod UID?
4. Why did deleting the Pod require `kubectl apply` to recover it?
5. What controller will Stage 1 add so a deleted application Pod is replaced?
6. What is the difference between kubectl, the API server, and the kubelet?

## What's next

Stage 1 deploys all ten Apollo Airlines components using Deployments, Services,
ConfigMaps, Secrets, ServiceAccounts, and Jobs. It then repeats this evidence
loop during a failed rolling update and rollback.
