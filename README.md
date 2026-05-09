# codex-assignment

Hello-world HTTP service. Deployed to a local minikube cluster via ArgoCD. Helm values are rendered from a Terraform module driven by Terragrunt.

## prerequisites

```bash
brew install minikube kubectl helm terraform terragrunt
```

## layout

```
helm/             # helm chart — Deployment + Service + ConfigMap + readiness probe + NetworkPolicy
modules/app/      # terraform module — renders a helm values file from 4 inputs
envs/dev/app/     # terragrunt config — dev-environment inputs
argocd/           # ArgoCD Application manifest
```

## deploy from scratch

```bash
# 1. clone
git clone https://github.com/DanielLuponenko/codex-assignment.git
cd codex-assignment

# 2. start minikube
#    use --cni=calico if you want NetworkPolicy actually enforced
minikube start

# 3. install argocd
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# --server-side avoids the "annotations too long" error on the ApplicationSet CRD

# 4. apply the application — wait for Synced + Healthy
kubectl apply -f argocd/application.yaml
# force argocd to sync immediately (otherwise it polls every ~3 min)
kubectl annotate app -n argocd hello-world-codex-assignment \
  argocd.argoproj.io/refresh=hard --overwrite
kubectl get application -n argocd -w

# 5. verify
kubectl get pods -n hello-app
kubectl port-forward -n hello-app svc/hello-world-codex-assignment 8080:80
# open http://localhost:8080 in a browser
```

## changing dev values

Per-env knobs (name, image, replicas, port) live in `envs/dev/app/terragrunt.hcl`. To change them:

```bash
cd envs/dev/app
terragrunt apply                   # re-renders helm/values-dev.yaml
cd -
git add envs/dev/app/terragrunt.hcl helm/values-dev.yaml
git commit -m "scale dev replicas" && git push
kubectl annotate app -n argocd hello-world-codex-assignment \
  argocd.argoproj.io/refresh=hard --overwrite
```

helm merges `values.yaml` (chart defaults) with `values-dev.yaml` (rendered overrides) — second file wins on conflicting keys.

## design notes

**resource requests/limits** — chart sets `requests: 25m / 16Mi`, `limits: 100m / 64Mi`. nginx serving a tiny static page idles near zero, so requests sit just above its honest baseline (multiple pods schedule comfortably on a small local cluster). Limits are ~4× requests so a brief spike survives but a runaway can't starve the node — the memory limit deliberately stays tight (64Mi) since this workload should never legitimately need more.

**readiness probe** — `httpGet /` on the app port, every 5s, 2s initial delay. The pod is added to the Service's endpoints only after the first probe succeeds; if it fails 3 consecutive times (the K8s default `failureThreshold`) the pod is removed from endpoints again. The probe controls *traffic flow*: a not-ready pod stops receiving new requests, but it isn't killed. Restarting is the job of liveness, not readiness.

**no liveness probe** — deliberate. Liveness exists to catch processes that are alive but stuck (deadlocks, exhausted thread pools). nginx serving static files from a ConfigMap doesn't deadlock — if the process is up, it's serving. A liveness probe here would only add restart risk on transient probe slowness with no real upside. If the pod truly hangs, the readiness probe already removes it from rotation; for a stateless workload that's enough.

**NetworkPolicy** — default-deny policy that selects pods by `app: <name>`, then explicitly allows:
- **Ingress** on TCP `{{ .Values.port }}` from anywhere — so `kubectl port-forward` and any in-cluster client reaching the app port works
- **Egress** only to `kube-system` on TCP/UDP 53 — DNS resolution

Anything else (other ports, other destinations, other protocols) is implicitly denied. nginx serving a static page doesn't need outbound HTTP/S3/etc., so locking egress signals intent without breaking anything. **Caveat:** minikube's default CNI (`kindnet`) silently ignores NetworkPolicy resources, so the policy exists in the cluster but doesn't actually filter traffic. Start with `minikube start --cni=calico` to see it enforce.

## argocd UI (optional)

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# open https://localhost:8080  (user: admin)
```

## cleanup

```bash
kubectl delete -f argocd/application.yaml
kubectl delete namespace argocd
minikube delete
```