# EMQX Load Test on GKE

## Run once

```bash
gcloud init
gcloud auth login
gcloud components update
export PROJECT=clear-healer-407411
gcloud auth application-default set-quota-project $PROJECT
gcloud config set project $PROJECT
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud config set compute/region europe-central2
gcloud config set compute/zone europe-central2-a
./create-gke.sh
```

## Install emqx

```bash
./install-emqx-operator.sh
kubectl create namespace emqx
kubectl apply -f emqx.yaml
kubectl -n emqx wait --for=condition=Ready --all pods
# dashboard IP
kubectl -n emqx get svc emqx-dashboard -o json | jq -r '.status.loadBalancer.ingress[0].ip'
# mqtt listner IP
kubectl -n emqx get svc emqx-listeners -o json | jq -r '.status.loadBalancer.ingress[0].ip'
```

## Install loadgen

```bash
./create-instance.sh loadgen
./generate-ansible-inventory.sh
ansible-playbook -vv ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get svc emqx-listeners -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
ansible loadgen -m command -a 'systemctl start emqtt-bench' --become
```
