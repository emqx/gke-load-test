# EMQX Load Test on GKE

## Pre-requisites

- [gcloud](https://cloud.google.com/sdk/docs/install)
- [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip)

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
```

## Install emqx

```bash
./create-gke.sh
./install-emqx-operator.sh
kubectl create namespace emqx
kubectl apply -f emqx.yaml
kubectl -n emqx wait --for=condition=Ready --all pods --timeout=120s
kubectl -n emqx get svc emqx-dashboard
kubectl apply -f ilb-svc.yaml
# debug: kubectl get events --all-namespaces --watch
```

## Install loadgen

```bash
for i in $(seq 1 5); do gcloud compute instances create loadgen-$i --network-interface "subnet=default,aliases=10.186.$i.0/28"  --image-project=ubuntu-os-cloud --image-family=ubuntu-2204-lts --machine-type=e2-standard-2 &; done
# wait for all instances to be ready
# init ssh connection
gcloud compute ssh loadgen-1
# may need to adjust the subnet prefix based on region
# this one is for europe-central2-a
./generate-ansible-inventory.sh '10.186' 16
ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get svc ilb -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
ansible loadgen -m command -a 'systemctl start emqtt-bench' --become
```

## Cleanup

```bash
gcloud compute instances delete $(seq -s ' ' -f 'loadgen-%g' 1 5)
gcloud container clusters delete emqx
```
