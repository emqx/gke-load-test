# EMQX Load Test on GKE

## Pre-requisites

- [gcloud](https://cloud.google.com/sdk/docs/install)
- [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip)

## Run once

```bash
gcloud init
gcloud auth login
gcloud components update
export PROJECT=<your project id>
gcloud auth application-default set-quota-project $PROJECT
gcloud config set project $PROJECT
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud config set compute/region europe-central2
gcloud config set compute/zone europe-central2-a
```

## Install emqx

```bash
gcloud container clusters create emqx \
    --machine-type e2-standard-8 \
    --zone europe-central2-a \
    --node-locations europe-central2-a
gcloud container clusters get-credentials emqx
./generate-ansible-inventory.sh
ansible-playbook ansible/gke.yml
./install-emqx-operator.sh
kubectl create namespace emqx
kubectl apply -f emqx.yaml
# give it a few sec before running the next command
kubectl -n emqx wait --for=condition=Ready --all pods --timeout=120s
kubectl -n emqx get svc emqx-dashboard
# debug: kubectl get events --all-namespaces --watch
```

## Install loadgen

```bash
for i in $(seq 1 5); do gcloud compute instances create loadgen-$i --network-interface "subnet=default,aliases=10.186.$((i+1)).0/28" --image-project=ubuntu-os-cloud --image-family=ubuntu-2204-lts --machine-type=e2-standard-4 &; done
# wait for all instances to be ready
# init ssh connection
gcloud compute ssh loadgen-1
# may need to adjust the subnet prefix based on region
# this one is for europe-central2-a
./generate-ansible-inventory.sh '10.186' 16
ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get endpoints/emqx-listeners -o json | jq '.subsets[].addresses | map(.ip) | join(",")' -r)"
ansible loadgen -m command -a 'systemctl start emqtt-bench' --become
```

## Cleanup

```bash
gcloud compute instances delete $(seq -s ' ' -f 'loadgen-%g' 1 5)
gcloud container clusters delete emqx
```

## Troubleshoting

```bash
# ssh on the pool machine
gcloud compute ssh gke-emqx-default-pool-8ffb4312-bjcg
# list pods
crictl pods
# list containers
crictl ps
# get normal shell (then you can apt-get update, etc)
/usr/bin/toolbox
```
