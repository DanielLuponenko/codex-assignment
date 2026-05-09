basic hellow world function

dependencies:
- kubectl
- helm
- minikube

basic functionality
commands: 
minikube start
helm install hello helm

wait for the pod to be in a Running state 

kubectl port-forward svc/hello-world-codex-assignment 5678:5678

curl http://localhost:5678/ 



argocd application - install 

kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml # used --server-side to avoide this error " Too long: may not be more than 262144 bytes "


kubectl apply -f argocd/application.yaml

test hello pod 
kubectl get pods -n hello-app
after in a runnign state do portworward again and test with curl 