# codex-assignment

Hello-world HTTP service. Deployed to a local minikube cluster via ArgoCD. Helm values are rendered from a Terraform module driven by Terragrunt.

## prerequisites

```bash
brew install minikube kubectl helm terraform terragrunt
```

## layout

```
helm/                # the helm chart (Deployment + Service + readiness probe)
modules/app/         # terraform module — renders a helm values file from 4 inputs
envs/dev/app/        # terragrunt config — dev-environment inputs
argocd/              # ArgoCD Application manifest
```

## deploy from scratch

### 1. clone

```bash
git clone https://github.com/DanielLuponenko/codex-assignment.git
cd codex-assignment
```

### 2. start minikube

```bash
minikube start
```

### 3. install argocd

```bash
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# --server-side avoids the "annotations too long" error on the ApplicationSet CRD

kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
```

### 4. apply the application

```bash
kubectl apply -f argocd/application.yaml
kubectl get application -n argocd -w
```

wait for `Synced` + `Healthy`.

### 5. verify

```bash
kubectl get pods -n hello-app
kubectl port-forward -n hello-app svc/hello-world-codex-assignment 5678:5678
curl http://localhost:5678/
# → Hello World
```

## changing dev values (terragrunt)

Per-env knobs (name, image, replicas, port) live in `envs/dev/app/terragrunt.hcl`. To change them:

1. edit the input you want, e.g. bump `replicas`
2. re-render the values file:
   ```bash
   cd envs/dev/app
   terragrunt apply
   ```
3. commit + push so argocd sees it:
   ```bash
   cd -
   git add envs/dev/app/terragrunt.hcl helm/values-dev.yaml
   git commit -m "scale dev replicas"
   git push
   ```
4. force argocd to refresh now (or wait ~3 min for the next poll):
   ```bash
   kubectl annotate app -n argocd hello-world-codex-assignment \
     argocd.argoproj.io/refresh=normal --overwrite
   ```

helm merges `values.yaml` (chart defaults) with `values-dev.yaml` (rendered overrides) — second file wins on conflicting keys.

## argocd UI (optional)

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# admin password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# open https://localhost:8080  (user: admin)
```

## cleanup

```bash
kubectl delete -f argocd/application.yaml
kubectl delete namespace argocd
minikube delete
```