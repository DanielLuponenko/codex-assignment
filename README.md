# codex-assignment

Hello-world HTTP service deployed to a local minikube cluster — installable via Helm or as a gitops sync via ArgoCD. Helm values are rendered from a Terraform module so per-environment knobs live in code, not hand-edited YAML.

## prerequisites

```bash
brew install minikube kubectl helm terraform
```

## layout

```
helm/                 # the helm chart (Deployment + Service + readiness probe)
modules/app/          # terraform module — renders a helm values file from 4 inputs
argocd/               # ArgoCD Application manifest
README.md
```

## quick local test

Sanity-check the chart on its own.

```bash
minikube start
helm install hello helm
```

wait for the pod to be Running:
```bash
kubectl get pods -w
```

then:
```bash
kubectl port-forward svc/hello-world-codex-assignment 5678:5678
curl http://localhost:5678/
```

clean up:
```bash
helm uninstall hello
```

## argocd

install argocd into the cluster:
```bash
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# --server-side avoids the "annotations too long" error on the ApplicationSet CRD
```

wait for argocd to come up:
```bash
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
```

apply the application — argocd will pull the chart from this repo:
```bash
kubectl apply -f argocd/application.yaml
```

watch it sync (look for `Synced` + `Healthy`):
```bash
kubectl get application -n argocd -w
```

verify and curl:
```bash
kubectl get pods -n hello-app
kubectl port-forward -n hello-app svc/hello-world-codex-assignment 5678:5678
curl http://localhost:5678/
```

### argocd UI (optional)

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# admin password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# open https://localhost:8080  (user: admin)
```

## terraform module

`modules/app/` takes 4 inputs (name, image, replicas, port) and renders a Helm values file.

quick test:

```bash
cd modules/app
terraform init
terraform apply \
  -var 'name=hello-world-codex-assignment' \
  -var 'image=hashicorp/http-echo:1.0.0' \
  -var 'replicas=2' \
  -var 'port=5678' \
  -var 'values_output_path=/tmp/test-values.yaml'

cat /tmp/test-values.yaml
```

clean up:
```bash
terraform destroy -auto-approve \
  -var 'name=hello-world-codex-assignment' \
  -var 'image=hashicorp/http-echo:1.0.0' \
  -var 'replicas=2' \
  -var 'port=5678' \
  -var 'values_output_path=/tmp/test-values.yaml'
```

(terragrunt wraps this so you don't pass `-var` flags manually — coming next.)

## cleanup

```bash
kubectl delete -f argocd/application.yaml
kubectl delete namespace argocd
minikube delete
```