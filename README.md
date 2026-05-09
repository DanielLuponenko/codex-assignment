# codex-assignment

Hello-world HTTP service. Deployed to a local minikube cluster via ArgoCD. Helm values are rendered from a Terraform module driven by Terragrunt.

## prerequisites

```bash
brew install minikube kubectl helm terraform terragrunt
```

## layout

```
helm/             # helm chart — Deployment + Service + readiness probe + NetworkPolicy
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
kubectl get application -n argocd -w

# 5. verify
kubectl get pods -n hello-app
kubectl port-forward -n hello-app svc/hello-world-codex-assignment 5678:5678
curl http://localhost:5678/    # → Hello World
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
  argocd.argoproj.io/refresh=normal --overwrite
```

helm merges `values.yaml` (chart defaults) with `values-dev.yaml` (rendered overrides) — second file wins on conflicting keys.

## design notes

**resource requests/limits** — chart sets `requests: 25m / 16Mi`, `limits: 100m / 64Mi`. http-echo is a tiny Go binary that idles near zero, so requests sit just above its honest baseline (multiple pods schedule comfortably on a small local cluster). Limits are ~4× requests so a brief spike survives but a runaway can't starve the node — the memory limit deliberately stays tight (64Mi) since http-echo allocating more would indicate a real bug worth crashing on.

**NetworkPolicy** — the chart ships a default-deny policy: ingress only on the app port, egress only to kube-system DNS. Minikube's default CNI (`kindnet`) silently ignores NetworkPolicy resources, so the policy exists in the cluster but doesn't actually filter traffic. Start with `minikube start --cni=calico` to see it enforce.

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